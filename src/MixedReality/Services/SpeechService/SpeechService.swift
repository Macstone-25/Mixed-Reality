//
//  SpeechService.swift
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

enum SpeechServiceError: Error {
    case configError(String)
    case apiError(String)
    case runtimeError(String)
    case permissionError(String)
}

@MainActor
class SpeechService: WebSocketDelegate {
    private let logger = Logger(subsystem: "SpeechService", category: "Services")
    
    private let artifacts: ArtifactService
    private let experiment: ExperimentModel
    private let config: DeepgramConfig
    
    /// Fired any time a transcript chunk is received from Deepgram
    let transcriptChunkEvent = PassthroughSubject<TranscriptChunk, Never>()
    
    private var socket: Starscream.WebSocket
    private var isConnected = false
    
    private let audioEngine = AVAudioEngine()
    private let audioFormat: AVAudioFormat
    
    private let assetWriter: AVAssetWriter
    private let assetWriterInput: AVAssetWriterInput
    
    private let processingQueue = DispatchQueue(label: "SpeechService", qos: .userInitiated)
    private let jsonDecoder = JSONDecoder()
    
    init(artifacts: ArtifactService, experiment: ExperimentModel, config: DeepgramConfig) async throws {
        self.artifacts = artifacts
        self.experiment = experiment
        self.config = config
        
        // MARK: Create AssetWriter
        
        let fileURL = try await artifacts.getFileURL(name: "conversation.m4a")
        assetWriter = try AVAssetWriter(outputURL: fileURL, fileType: .m4a)
        
        audioFormat = audioEngine.inputNode.inputFormat(forBus: 0)
        guard audioFormat.channelCount > 0, audioFormat.sampleRate > 0 else {
            throw SpeechServiceError.runtimeError(
                "Invalid input format — channels: \(audioFormat.channelCount), sample rate: \(audioFormat.sampleRate)")
        }
        
        assetWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: audioFormat.sampleRate,
            AVNumberOfChannelsKey: audioFormat.channelCount,
            AVEncoderBitRateKey: 128000
        ])
        
        if assetWriter.canAdd(assetWriterInput) {
            assetWriterInput.expectsMediaDataInRealTime = true
            assetWriter.add(assetWriterInput)
        }
        
        // MARK: Create WebSocket
        
        var urlComponents = URLComponents()
        urlComponents.scheme = "wss"
        urlComponents.host = "api.deepgram.com"
        urlComponents.path = "/v1/listen"
        urlComponents.queryItems = [
            // MARK: Constant
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "sample_rate", value: String(audioFormat.sampleRate)),
            // MARK: Configurable
            URLQueryItem(name: "model", value: config.model),
            URLQueryItem(name: "language", value: config.language),
            URLQueryItem(name: "channels", value: String(config.channels)),
            URLQueryItem(name: "endpointing", value: String(config.endpointingMs)),
            URLQueryItem(name: "diarize", value: config.diarize ? "true" : "false"),
            URLQueryItem(name: "punctuate", value: config.punctuate ? "true" : "false"),
            URLQueryItem(name: "filler_words", value: config.fillerWords ? "true" : "false"),
            URLQueryItem(name: "interim_results", value: config.interimResults ? "true" : "false"),
            URLQueryItem(name: "vad_events", value: config.vadEvents ? "true" : "false")
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
        socket.delegate = self
    }

    /// Connects to Deepgram and begins streaming audio
    func connect() async throws {
        guard isConnected == false else {
            throw SpeechServiceError.runtimeError("Already connected")
        }
        
        // Obtain microphone access
        let isPermissionGranted = await AVAudioApplication.requestRecordPermission()
        guard isPermissionGranted else {
            throw SpeechServiceError.permissionError("Recording permission was not granted")
        }
        
        // Configure and enable AudioEngine
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: audioFormat) { [weak self] buffer, time in
            self?.processingQueue.async {
                self?.processAudioBuffer(buffer: buffer, time: time)
            }
        }
        try audioEngine.start()
        
        // Connect to Deepgram via WebSocket
        // TODO: Start sending KeepAlive at this point (https://developers.deepgram.com/docs/audio-keep-alive)
        await artifacts.logEvent(type: "SpeechService", message: "Connecting to \(socket.request.url?.absoluteString ?? "nil")")
        socket.connect()
        isConnected = true
    }
    
    /// Disconnect from Deepgram WebSocket and deactivate microphone
    func disconnect() async throws {
        guard isConnected == true else {
            throw SpeechServiceError.runtimeError("Already disconnected")
        }
        
        await artifacts.logEvent(type: "SpeechService", message: "Disconnecting...")
        isConnected = false
        
        // Disconnect audio engine
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.reset()
        
        // Disconnect WebSocket
        socket.disconnect(closeCode: 1000)
        await artifacts.logEvent(type: "SpeechService", message: "WebSocket disconnected")
        
        // Disconnect AssetWriter (and AssetWriterInput)
        await assetWriter.finishWriting()
        if let error = assetWriter.error {
            await artifacts.logEvent(type: "SpeechService", message: "AssetWriter error: \(error.localizedDescription)")
        } else {
            await artifacts.logEvent(type: "SpeechService", message: "Audio recording saved to \(assetWriter.outputURL)")
        }
    }
    
    /// Handles WebSocket events: connection, disconnection, incoming messages, and errors
    func didReceive(event: Starscream.WebSocketEvent, client: any Starscream.WebSocketClient) {
        switch event {
        case .connected(let headers):
            Task {
                await artifacts.logEvent(type: "Deepgram", message: "WebSocket connected with headers: \(headers)")
            }
        case .disconnected(let reason, let code):
            // TODO: depending on the code, attempt to reconnect
            Task {
                await artifacts.logEvent(type: "Deepgram", message: "WebSocket disconnected (\(code)): \(reason)")
            }
        case .text(let text):
            if let data = text.data(using: .utf8) {
                do {
                    try processJSON(data: data)
                } catch {
                    Task {
                        await artifacts.logEvent(type: "Deepgram", message: "Failed to parse Deepgram response: \(error.localizedDescription)")
                    }
                }
            }
        case .error(let error):
            Task {
                if let error = error {
                    await artifacts.logEvent(type: "Deepgram", message: "WebSocket error: \(error.localizedDescription)")
                } else {
                    await artifacts.logEvent(type: "Deepgram", message: "WebSocket error: unknown")
                }
            }
        default:
            logger.warning("Unhandled WebSocketEvent")
            break
        }
    }
    
    /// Performs format conversions and sends audio data to the WebSocket and AssetWriter
    private func processAudioBuffer(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard isConnected else { return }
        
        // Send audio buffer to Deepgram via WebSocket (in PCM16 format)
        if let pcmData = AudioBufferUtils.convertBufferToPCM16(buffer: buffer, targetChannelCount: config.channels) {
            socket.write(data: pcmData)
        }

        // Send audio buffer to asset writer (in native format)
        if let sampleBuffer = AudioBufferUtils.cmSampleBufferFromPCM(buffer) {
            if assetWriter.status == .unknown {
                let startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                if assetWriter.startWriting() {
                    assetWriter.startSession(atSourceTime: startTime)
                }
            }

            if assetWriter.status == .writing && assetWriterInput.isReadyForMoreMediaData {
                assetWriterInput.append(sampleBuffer)
            }
        }
    }
    
    /// Parses JSON data into TranscriptChunk events
    private func processJSON(data: Data) throws {
        // We are only interested in Results data frames, the rest can be ignored
        let envelope = try jsonDecoder.decode(DeepgramEnvelope.self, from: data)
        guard envelope.type == "Results" else { return }
        
        let results = try jsonDecoder.decode(DeepgramResults.self, from: data)
        
        // We can only handle one interpretation, so we take the most likely option and ignore other alternatives
        // If this result was empty (i.e. there are no words), we simply ignore it and continue
        guard let words = results.channel.alternatives.first?.words, !words.isEmpty else {
            return
        }
        
        // Assemble full diarized sentences from individually diarized words
        var speakerSentences: [String: (text: String, start: Double, end: Double)] = [:]
        for wordInfo in words {
            let speakerID = wordInfo.speaker.map { "Speaker:\($0)" } ?? "Speaker:Unknown"
            let word = wordInfo.punctuated_word ?? wordInfo.word
            if var entry = speakerSentences[speakerID] {
                entry.text += " " + word
                entry.end = wordInfo.end
                speakerSentences[speakerID] = entry
            } else {
                speakerSentences[speakerID] = (text: word, start: wordInfo.start, end: wordInfo.end)
            }
        }
        
        // Emit a TranscriptChunk for each speaker with a non-empty utterance
        for (speakerID, entry) in speakerSentences {
            let trimmedText = entry.text.trimmingCharacters(in: .whitespaces)
            guard !trimmedText.isEmpty else { continue }
            
            let chunk = TranscriptChunk(
                text: trimmedText,
                speakerID: speakerID,
                isFinal: results.is_final,
                startAt: entry.start,
                endAt: entry.end,
            )
            
            logger.info("\(chunk.isFinal ? "✅" : "❓") [\(chunk.speakerID)]: \(chunk.text)")
            transcriptChunkEvent.send(chunk)
        }
    }
}

