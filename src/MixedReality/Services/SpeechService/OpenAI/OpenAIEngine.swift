//
//  OpenAIEngine.swift
//  MixedReality
//

import Foundation
import Combine
import Starscream
import AVFoundation
import OSLog

/// OpenAI Realtime API message envelope
private struct RealtimeEnvelope: Codable {
    let type: String
}

/// Session configuration sent on connect
private struct SessionUpdateMessage: Codable {
    var type = "session.update"
    let session: SessionConfig
    
    struct SessionConfig: Codable {
        let modalities: [String]
        let instructions: String
        let voice: String
        let input_audio_format: String
        let output_audio_format: String
        let input_audio_transcription: TranscriptionConfig?
        let turn_detection: TurnDetectionConfig?
        
        struct TranscriptionConfig: Codable {
            let model: String
        }
        
        struct TurnDetectionConfig: Codable {
            let type: String
            let threshold: Double?
            let prefix_padding_ms: Int?
            let silence_duration_ms: Int?
        }
    }
}

/// Audio chunk sent to the API
private struct AudioAppendMessage: Codable {
    var type = "input_audio_buffer.append"
    let audio: String  /// base64-encoded PCM16
}

/// Transcript delta event from the API
private struct TranscriptionComplete: Codable {
    let type: String
    let item_id: String
    let content_index: Int
    let transcript: String
}

/// Transcript partial results
private struct TranscriptionPartial: Codable {
    let type: String
    let item_id: String
    let content_index: Int
    let delta: String
}

class OpenAIEngine: NSObject, SpeechEngine, WebSocketDelegate {
    private let logger = Logger(subsystem: "OpenAIRealtimeSpeechEngine", category: "Services")

    /// Fired any time a transcript chunk is received
    let transcriptChunkEvent = PassthroughSubject<TranscriptChunk, Never>()

    private let artifacts: ArtifactService
    private let config: OpenAIConfig

    private var socket: Starscream.WebSocket
    private var sessionStartTime: Date = Date()

    /// Tracks partial transcripts by item_id for delta accumulation
    private var partialTranscripts: [String: String] = [:]

    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()

    init(
        artifacts: ArtifactService,
        config: OpenAIConfig = OpenAIConfig()
    ) throws {
        self.config = config
        self.artifacts = artifacts

        /// Construct OpenAI Realtime API WebSocket URL
        guard let url = URL(string: "wss://api.openai.com/v1/realtime?model=\(config.model)")
        else {
            throw SpeechServiceError.apiError("Invalid OpenAI Realtime WebSocket URL for model: \(config.model)")
        }

        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            throw SpeechServiceError.apiError("OPENAI_API_KEY not set")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")

        socket = Starscream.WebSocket(request: request)

        super.init()
        socket.delegate = self
    }

    /// Called once during SpeechService.connect() — connects to OpenAI Realtime API and configures session
    func start() async throws {
        sessionStartTime = Date()
        partialTranscripts.removeAll()

        await artifacts.logEvent(
            type: "OpenAIRealtimeSpeechEngine",
            message: "Connecting to \(socket.request.url?.absoluteString ?? "nil")"
        )

        socket.connect()
    }

    /// Called once during SpeechService.disconnect() — closes WebSocket
    func stop() async {
        socket.disconnect(closeCode: 1000)
        await artifacts.logEvent(type: "OpenAIRealtimeSpeechEngine", message: "Disconnected")
    }

    /// Called for every audio buffer captured by the microphone tap — sends base64-encoded PCM16 to OpenAI
    func processAudioBuffer(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard let pcmData = AudioBufferUtils.convertBufferToPCM16(
            buffer: buffer,
            targetChannelCount: 1  // OpenAI Realtime expects mono
        ) else { return }

        let base64Audio = pcmData.base64EncodedString()

        let message = AudioAppendMessage(audio: base64Audio)

        guard let jsonData = try? jsonEncoder.encode(message),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            logger.warning("Failed to encode audio append message")
            return
        }

        socket.write(string: jsonString)
    }

    /// Starscream WebSocket delegate method for handling connection, messages, and errors
    func didReceive(event: Starscream.WebSocketEvent, client: any Starscream.WebSocketClient) {
        Task {
            switch event {
            case .connected:
                await artifacts.logEvent(type: "OpenAI", message: "WebSocket connected")
                await sendSessionConfiguration()

            case .peerClosed:
                await artifacts.logEvent(type: "OpenAI", message: "WebSocket closed")

            case .cancelled:
                await artifacts.logEvent(type: "OpenAI", message: "WebSocket cancelled")

            case .disconnected(let reason, let code):
                await artifacts.logEvent(
                    type: "OpenAI",
                    message: "WebSocket disconnected (\(code)): \(reason)"
                )

            case .text(let text):
                if let data = text.data(using: .utf8) {
                    do {
                        try await processJSON(data: data)
                    } catch {
                        await artifacts.logEvent(
                            type: "OpenAI",
                            message: "Failed to parse response: \(error.localizedDescription)"
                        )
                    }
                }

            case .error(let error):
                await artifacts.logEvent(
                    type: "OpenAI",
                    message: "WebSocket error: \(error?.localizedDescription ?? "unknown")"
                )

            default:
                await artifacts.logEvent(
                    type: "OpenAI",
                    message: "Unhandled WebSocketEvent: \(String(describing: event))"
                )
            }
        }
    }

    /// Sends session configuration immediately after connection
    private func sendSessionConfiguration() async {
        let config = SessionUpdateMessage(
            session: SessionUpdateMessage.SessionConfig(
                modalities: config.modalities,
                instructions: config.instructions,
                voice: config.voice,
                input_audio_format: config.inputAudioFormat,
                output_audio_format: config.outputAudioFormat,
                input_audio_transcription: SessionUpdateMessage.SessionConfig.TranscriptionConfig(
                    model: config.transcriptionModel
                ),
                turn_detection: SessionUpdateMessage.SessionConfig.TurnDetectionConfig(
                    type: config.turnDetectionType,
                    threshold: config.turnDetectionThreshold,
                    prefix_padding_ms: config.turnDetectionPrefixPaddingMs,
                    silence_duration_ms: config.turnDetectionSilenceDurationMs
                )
            )
        )

        guard let jsonData = try? jsonEncoder.encode(config),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            await artifacts.logEvent(
                type: "OpenAIRealtimeSpeechEngine",
                message: "Failed to encode session configuration"
            )
            return
        }

        socket.write(string: jsonString)

        await artifacts.logEvent(
            type: "OpenAIRealtimeSpeechEngine",
            message: "Session configuration sent"
        )
    }

    /// Parses JSON events from the Realtime API
    private func processJSON(data: Data) async throws {
        let envelope = try jsonDecoder.decode(RealtimeEnvelope.self, from: data)

        switch envelope.type {
        case "conversation.item.input_audio_transcription.completed":
            try await handleTranscriptionCompleted(data: data)

        case "conversation.item.input_audio_transcription.delta":
            try await handleTranscriptionPartial(data: data)

        case "session.created", "session.updated":
            await artifacts.logEvent(type: "OpenAI", message: "Session \(envelope.type)")

        case "error":
            if let errorString = String(data: data, encoding: .utf8) {
                await artifacts.logEvent(type: "OpenAI", message: "Error: \(errorString)")
            }

        default:
            // Many event types we don't need to handle (input_audio_buffer.committed, etc.)
            break
        }
    }

    /// Handles completed transcription events (final results)
    private func handleTranscriptionCompleted(data: Data) async throws {
        let event = try jsonDecoder.decode(TranscriptionComplete.self, from: data)

        let trimmedText = event.transcript.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty else { return }

        /// Clear any partial state for this item
        partialTranscripts.removeValue(forKey: event.item_id)
        
        let endAt = Date().timeIntervalSince(sessionStartTime)
        let speechDuration = estimatedSpeechDuration(for: trimmedText)

        let chunk = TranscriptChunk(
            text: trimmedText,
            speakerID: "Speaker:User", // OpenAI currently does not support multiple speaker IDs
            isFinal: true,
            startAt: max(0, endAt - speechDuration),
            endAt: endAt
        )

        let timeRange = String(format: "(%.1fs - %.1fs)", chunk.startAt, chunk.endAt)
        let logMessage = "\(timeRange) \(chunk)"

        logger.info("\(logMessage)")
        await artifacts.logEvent(type: "Transcript", message: logMessage)

        transcriptChunkEvent.send(chunk)
    }

    /// Handles partial transcriptions
    private func handleTranscriptionPartial(data: Data) async throws {
        let event = try jsonDecoder.decode(TranscriptionPartial.self, from: data)

        /// Accumulate deltas for this item
        let existing = partialTranscripts[event.item_id] ?? ""
        let updated = existing + event.delta
        partialTranscripts[event.item_id] = updated

        let trimmedText = updated.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty else { return }

        /// Approximate timing window for interim partial results.
        /// This is intentionally separate from the window used for final transcripts.
        let endAt = Date().timeIntervalSince(sessionStartTime)
        let speechDuration = estimatedSpeechDuration(for: trimmedText)

        // Show only the *most recent* part of speech
        let partialWindow = min(speechDuration, 1.2)

        let chunk = TranscriptChunk(
            text: trimmedText,
            speakerID: "Speaker:User",
            isFinal: false,
            startAt: max(0, endAt - partialWindow),
            endAt: endAt
        )

        let timeRange = String(format: "(%.1fs - %.1fs)", chunk.startAt, chunk.endAt)
        let logMessage = "\(timeRange) \(chunk)"

        logger.info("\(logMessage)")

        transcriptChunkEvent.send(chunk)
    }
    
    private func estimatedSpeechDuration(for text: String) -> TimeInterval {
        let words = text.split(whereSeparator: \.isWhitespace).count
        return Double(words) / config.wordsPerSecond
    }

}
