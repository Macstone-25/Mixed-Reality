//
//  DeepgramEngine.swift
//  MixedReality
//

import Foundation
import Combine
import Starscream
import AVFoundation
import OSLog

/// Standard message envelope indicating the message type (e.g. Results, SpeechStarted, ...)
private struct DeepgramEnvelope: Codable {
    let type: String?
}

/// Deepgram Results format
private struct DeepgramResults: Codable {
    let is_final: Bool
    let channel: Channel

    struct Channel: Codable {
        let alternatives: [Alternative]
    }

    struct Alternative: Codable {
        let transcript: String
        let words: [Word]
    }

    struct Word: Codable {
        let word: String
        let punctuated_word: String?
        let speaker: Int?
        let start: Double
        let end: Double
    }
}

class DeepgramEngine: NSObject, SpeechEngine, WebSocketDelegate {
    private let logger = Logger(subsystem: "DeepgramSpeechEngine", category: "Services")

    /// Fired any time a transcript chunk is received from Deepgram
    let transcriptChunkEvent = PassthroughSubject<TranscriptChunk, Never>()

    private let artifacts: ArtifactService
    private let config: DeepgramConfig

    private var socket: Starscream.WebSocket
    private var keepAliveTimer: Timer?

    private let jsonDecoder = JSONDecoder()

    init(
        artifacts: ArtifactService,
        config: DeepgramConfig
    ) throws {
        self.artifacts = artifacts
        self.config = config
        
        let sampleRate = AVAudioSession.sharedInstance().sampleRate

        /// Construct Deepgram WebSocket URL with audio and transcription parameters
        var urlComponents = URLComponents()
        urlComponents.scheme = "wss"
        urlComponents.host = "api.deepgram.com"
        urlComponents.path = "/v1/listen"
        urlComponents.queryItems = [
            URLQueryItem(name: "encoding",        value: "linear16"),
            URLQueryItem(name: "sample_rate",     value: String(Int(sampleRate))),
            URLQueryItem(name: "model",           value: config.model),
            URLQueryItem(name: "language",        value: config.language),
            URLQueryItem(name: "channels",        value: String(config.channels)),
            URLQueryItem(name: "endpointing",     value: String(config.endpointingMs)),
            URLQueryItem(name: "diarize",         value: config.diarize ? "true" : "false"),
            URLQueryItem(name: "punctuate",       value: config.punctuate ? "true" : "false"),
            URLQueryItem(name: "filler_words",    value: config.fillerWords ? "true" : "false"),
            URLQueryItem(name: "interim_results", value: config.interimResults ? "true" : "false"),
            URLQueryItem(name: "vad_events",      value: config.vadEvents ? "true" : "false")
        ]

        guard let url = urlComponents.url else {
            throw SpeechServiceError.configError("Invalid WebSocket URL")
        }

        guard let deepgramKey = ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"] else {
            throw SpeechServiceError.apiError("DEEPGRAM_API_KEY not set")
        }

        var request = URLRequest(url: url)
        request.setValue("Token \(deepgramKey)", forHTTPHeaderField: "Authorization")

        socket = Starscream.WebSocket(request: request)

        super.init()
        socket.delegate = self
    }

    /// Called once during SpeechService.connect() — connects to Deepgram WebSocket and starts keep-alive
    func start() async throws {
        await artifacts.logEvent(
            type: "DeepgramSpeechEngine",
            message: "Connecting to \(socket.request.url?.absoluteString ?? "nil")"
        )

        socket.connect()

        keepAliveTimer?.invalidate()
        keepAliveTimer = Timer.scheduledTimer(
            withTimeInterval: 5.0,
            repeats: true
        ) { [weak self] _ in
            self?.sendKeepAlive()
        }
    }

    /// Called once during SpeechService.disconnect() — closes WebSocket and tears down keep-alive
    func stop() async {
        keepAliveTimer?.invalidate()
        keepAliveTimer = nil

        socket.disconnect(closeCode: 1000)

        await artifacts.logEvent(type: "DeepgramSpeechEngine", message: "Disconnected")
    }

    /// Called for every audio buffer captured by the microphone tap — sends PCM16 audio to Deepgram
    func processAudioBuffer(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        /// Send audio buffer to Deepgram via WebSocket (in PCM16 format)
        if let pcmData = AudioBufferUtils.convertBufferToPCM16(
            buffer: buffer,
            targetChannelCount: config.channels
        ) {
            socket.write(data: pcmData)
        }
    }

    /// Starscream WebSocket delegate method for handling connection, messages, and errors
    func didReceive(event: Starscream.WebSocketEvent, client: any Starscream.WebSocketClient) {
        Task {
            switch event {
            case .connected:
                await artifacts.logEvent(type: "Deepgram", message: "WebSocket connected")
            case .peerClosed:
                await artifacts.logEvent(type: "Deepgram", message: "WebSocket closed")
            case .cancelled:
                await artifacts.logEvent(type: "Deepgram", message: "WebSocket cancelled")
            case .disconnected(let reason, let code):
                await artifacts.logEvent(
                    type: "Deepgram",
                    message: "WebSocket disconnected (\(code)): \(reason)"
                )
            case .text(let text):
                if let data = text.data(using: .utf8) {
                    do {
                        try await processJSON(data: data)
                    } catch {
                        await artifacts.logEvent(
                            type: "Deepgram",
                            message: "Failed to parse Deepgram response: \(error.localizedDescription)"
                        )
                    }
                }
            case .error(let error):
                await artifacts.logEvent(
                    type: "Deepgram",
                    message: "WebSocket error: \(error?.localizedDescription ?? "unknown")"
                )
            default:
                await artifacts.logEvent(
                    type: "Deepgram",
                    message: "Unhandled WebSocketEvent: \(String(describing: event))"
                )
            }
        }
    }

    private func sendKeepAlive() {
        let keepAlive: [String: Any] = ["type": "KeepAlive"]
        do {
            let data = try JSONSerialization.data(withJSONObject: keepAlive, options: [])
            if let jsonString = String(data: data, encoding: .utf8) {
                socket.write(string: jsonString)
            } else {
                logger.warning("Failed to convert data to UTF-8 string: \(data)")
            }
        } catch {
            logger.warning("Failed to encode KeepAlive message: \(error)")
        }
    }

    /// Parses JSON data into TranscriptChunk events
    private func processJSON(data: Data) async throws {
        /// We are only interested in Results data frames, the rest can be ignored
        let envelope = try jsonDecoder.decode(DeepgramEnvelope.self, from: data)
        guard envelope.type == "Results" else { return }

        let results = try jsonDecoder.decode(DeepgramResults.self, from: data)

        /// We can only handle one interpretation, so we take the most likely option and ignore other alternatives
        /// If this result was empty (i.e. there are no words), we simply ignore it and continue
        guard let words = results.channel.alternatives.first?.words,
              !words.isEmpty else { return }

        /// Assemble full diarized sentences from individually diarized words
        var speakerSentences: [String: (text: String, start: Double, end: Double)] = [:]

        for wordInfo in words {
            let speakerID = wordInfo.speaker.map { "Speaker:\($0)" } ?? "Speaker:Unknown"
            let word = wordInfo.punctuated_word ?? wordInfo.word

            if var entry = speakerSentences[speakerID] {
                entry.text += " " + word
                entry.end = wordInfo.end
                speakerSentences[speakerID] = entry
            } else {
                speakerSentences[speakerID] = (
                    text: word,
                    start: wordInfo.start,
                    end: wordInfo.end
                )
            }
        }

        for (speakerID, entry) in speakerSentences {
            let trimmedText = entry.text.trimmingCharacters(in: .whitespaces)
            guard !trimmedText.isEmpty else { continue }

            let chunk = TranscriptChunk(
                text: trimmedText,
                speakerID: speakerID,
                isFinal: results.is_final,
                startAt: entry.start,
                endAt: entry.end
            )

            transcriptChunkEvent.send(chunk)
        }
    }
}
