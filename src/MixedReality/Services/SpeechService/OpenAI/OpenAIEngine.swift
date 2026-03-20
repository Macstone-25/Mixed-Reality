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

struct SpeechFragment {
    let startTime: TimeInterval
    var content: String
    var lastUpdated: Date = Date()
    
    // You could even calculate duration on the fly if needed
    func relativeTimestamp(from sessionStart: Date) -> TimeInterval {
        return Date().timeIntervalSince(sessionStart)
    }
}

class OpenAIEngine: NSObject, SpeechEngine, WebSocketDelegate {
    private let logger = Logger(subsystem: "OpenAIRealtimeSpeechEngine", category: "Services")

    /// OpenAI Realtime API requires exactly 24 kHz mono PCM16
    private static let targetSampleRate: Double = 24_000
    private static let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: targetSampleRate,
        channels: 1,
        interleaved: true
    )!

    /// Reusable converter — rebuilt whenever the input format changes
    private var audioConverter: AVAudioConverter?
    private var lastInputFormat: AVAudioFormat?

    /// Fired any time a transcript chunk is received
    let transcriptChunkEvent = PassthroughSubject<TranscriptChunk, Never>()

    private let artifacts: ArtifactService
    private let config: OpenAIConfig

    private var socket: Starscream.WebSocket
    private var sessionStartTime: Date = Date()

    /// Tracks partial transcripts by item_id for delta accumulation
    private var partialTranscripts: [String: SpeechFragment] = [:]

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

    /// Called for every audio buffer captured by the microphone tap.
    /// Resamples to mono PCM16 @ 24 kHz before sending to OpenAI.
    func processAudioBuffer(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard let pcm16Data = resampleToPCM16_24kHz(buffer: buffer) else {
            logger.warning("Failed to resample audio buffer to PCM16 24kHz")
            return
        }

        let base64Audio = pcm16Data.base64EncodedString()
        let message = AudioAppendMessage(audio: base64Audio)

        guard let jsonData = try? jsonEncoder.encode(message),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            logger.warning("Failed to encode audio append message")
            return
        }

        socket.write(string: jsonString)
    }

    /// Converts any AVAudioPCMBuffer to interleaved mono PCM16 at 24 kHz.
    /// Returns raw bytes ready to base64-encode and send to the Realtime API.
    ///
    /// The OpenAI Realtime API is strict: it expects exactly PCM16 @ 24 kHz mono.
    /// Sending the microphone's native rate (44.1 kHz or 48 kHz) causes the API
    /// to receive sped-up audio, producing hallucinated transcriptions.
    private func resampleToPCM16_24kHz(buffer: AVAudioPCMBuffer) -> Data? {
        let inputFormat = buffer.format

        /// Rebuild converter only when the upstream format changes (e.g. first call)
        if audioConverter == nil || lastInputFormat != inputFormat {
            guard let converter = AVAudioConverter(from: inputFormat, to: Self.targetFormat) else {
                logger.error(
                    "Cannot create AVAudioConverter: \(inputFormat) → PCM16 24kHz"
                )
                return nil
            }
            converter.downmix = true        /// fold stereo → mono if needed
            audioConverter  = converter
            lastInputFormat = inputFormat
            logger.info(
                "AVAudioConverter created: \(inputFormat.sampleRate) Hz → 24000 Hz"
            )
        }

        guard let converter = audioConverter else { return nil }

        /// Calculate the number of output frames proportional to the input
        let inputFrames  = AVAudioFrameCount(buffer.frameLength)
        let sampleRatio  = Self.targetSampleRate / inputFormat.sampleRate
        let outputFrames = AVAudioFrameCount((Double(inputFrames) * sampleRatio).rounded(.up))

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: Self.targetFormat,
            frameCapacity: outputFrames
        ) else {
            logger.error("Failed to allocate output AVAudioPCMBuffer")
            return nil
        }

        var conversionError: NSError?
        var sourceConsumed = false  /// AVAudioConverter input block is called repeatedly; supply data once

        let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            if sourceConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            outStatus.pointee = .haveData
            sourceConsumed = true
            return buffer
        }

        if status == .error || conversionError != nil {
            logger.error(
                "Audio conversion failed: \(conversionError?.localizedDescription ?? "unknown")"
            )
            return nil
        }

        guard outputBuffer.frameLength > 0 else { return nil }

        /// Copy raw Int16 samples into a Data blob (interleaved, mono)
        let frameCount = Int(outputBuffer.frameLength)
        let byteCount  = frameCount * 2     // 2 bytes per Int16 sample
        guard let int16Ptr = outputBuffer.int16ChannelData?.pointee else { return nil }

        return Data(bytes: int16Ptr, count: byteCount)
    }

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
            break
        }
    }

    private func handleTranscriptionCompleted(data: Data) async throws {
        let event = try jsonDecoder.decode(TranscriptionComplete.self, from: data)

        let trimmedText = event.transcript.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty else { return }

        partialTranscripts.removeValue(forKey: event.item_id)

        let endAt = Date().timeIntervalSince(sessionStartTime)
        let speechDuration = estimatedSpeechDuration(for: trimmedText)

        let chunk = TranscriptChunk(
            text: trimmedText,
            speakerID: "Speaker:User",
            isFinal: true,
            startAt: max(0, endAt - speechDuration),
            endAt: endAt
        )

        transcriptChunkEvent.send(chunk)
    }

    private func handleTranscriptionPartial(data: Data) async throws {
        let event = try jsonDecoder.decode(TranscriptionPartial.self, from: data)

        // Set a TTL for partials
        let ttl: TimeInterval = 60 // seconds
        let currTime = Date()
        
        // Remove items older than TTL seconds
        partialTranscripts = partialTranscripts.filter { _, fragment in
            currTime.timeIntervalSince(fragment.lastUpdated) < ttl
        }

        var existing = partialTranscripts[event.item_id] ?? SpeechFragment(
            startTime: Date().timeIntervalSince(sessionStartTime),
            content: ""
        )
        
        existing.content += event.delta
        existing.lastUpdated = currTime
        partialTranscripts[event.item_id] = existing

        let trimmedText = existing.content.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty else { return }

        let endAt = Date().timeIntervalSince(sessionStartTime)
        let speechDuration = estimatedSpeechDuration(for: trimmedText)
        let partialWindow = min(speechDuration, 1.2)

        let chunk = TranscriptChunk(
            text: trimmedText,
            speakerID: "Speaker:?",
            isFinal: false,
            startAt: max(0, endAt - partialWindow),
            endAt: endAt
        )

        transcriptChunkEvent.send(chunk)
    }

    private func estimatedSpeechDuration(for text: String) -> TimeInterval {
        let words = text.split(whereSeparator: \.isWhitespace).count
        return Double(words) / config.wordsPerSecond
    }
}
