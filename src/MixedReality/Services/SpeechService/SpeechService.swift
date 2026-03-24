//
//  SpeechService.swift
//  MixedReality
//

import Foundation
import Combine
import AVFoundation
import OSLog
import os

enum SpeechServiceError: Error {
    case configError(String)
    case apiError(String)
    case runtimeError(String)
    case permissionError(String)
}

class SpeechService {
    private let logger = Logger(subsystem: "SpeechService", category: "Services")

    private let artifacts: ArtifactService
    private let experiment: ExperimentModel
    private let anonymizer: (any AudioAnonymizer)?

    /// Fired any time a transcript chunk is received from the active SpeechEngine
    var transcriptChunkEvent: AnyPublisher<TranscriptChunk, Never> {
        engine.transcriptChunkEvent
            .handleEvents(receiveOutput: { [weak self] chunk in
                self?.logChunk(chunk)
            })
            .eraseToAnyPublisher()
    }

    private let engine: SpeechEngine

    private var isActive = false
    private var isConnected = false
    private var hasInputTapInstalled = false

    private let audioEngine = AVAudioEngine()
    private let audioFormat: AVAudioFormat

    private let assetWriter: AVAssetWriter
    private let assetWriterInput: AVAssetWriterInput
    private let conversationFileURL: URL
    private let outputName: String

    init(
        engine: SpeechEngines,
        artifacts: ArtifactService,
        experiment: ExperimentModel,
        anonymizer: (any AudioAnonymizer)? = nil
    ) async throws {
        self.artifacts = artifacts
        self.experiment = experiment
        self.anonymizer = anonymizer

        /// Configure audio session
        let isPermissionGranted = await AVAudioApplication.requestRecordPermission()
        guard isPermissionGranted else {
            throw SpeechServiceError.permissionError("Recording permission was not granted")
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.allowBluetoothA2DP, .defaultToSpeaker]
        )

        try session.setPreferredSampleRate(48_000)
        try session.setPreferredIOBufferDuration(0.005) // 5 ms
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        audioFormat = audioEngine.inputNode.inputFormat(forBus: 0)

        /// Initialize the correct SpeechEngine
        switch engine {
        case .openai:
            self.engine = try OpenAIEngine(
                artifacts: artifacts,
                config: OpenAIConfig()
            )

        case .deepgram:
            self.engine = try DeepgramEngine(
                artifacts: artifacts,
                config: DeepgramConfig(),
                audioFormat: audioFormat
            )
        }

        /// Create AssetWriter
        let fileURL = try await artifacts.getFileURL(name: "Conversation.m4a")
        self.conversationFileURL = fileURL
        self.outputName = "Anonymized_Conversation.m4a"

        assetWriter = try AVAssetWriter(outputURL: fileURL, fileType: .m4a)

        guard audioFormat.channelCount > 0, audioFormat.sampleRate > 0 else {
            throw SpeechServiceError.runtimeError(
                "Invalid input format — channels: \(audioFormat.channelCount), sample rate: \(audioFormat.sampleRate)"
            )
        }

        let sr = audioFormat.sampleRate
        let safeSampleRate: Double = (sr == 44_100 || sr == 48_000) ? sr : 48_000

        assetWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: safeSampleRate,
            AVNumberOfChannelsKey: min(Int(audioFormat.channelCount), 2),
            AVEncoderBitRateKey: 128_000
        ])

        if assetWriter.canAdd(assetWriterInput) {
            assetWriterInput.expectsMediaDataInRealTime = true
            assetWriter.add(assetWriterInput)
        }
        
        /// Construct Deepgram WebSocket URL with audio and transcription parameters
        var urlComponents = URLComponents()
        urlComponents.scheme = "wss"
        urlComponents.host = "api.deepgram.com"
        urlComponents.path = "/v1/listen"
        urlComponents.queryItems = [
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "sample_rate", value: String(Int(audioFormat.sampleRate))),
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
        
        guard
            let deepgramKey = ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"],
            !deepgramKey.isEmpty
        else {
            throw SpeechServiceError.apiError("DEEPGRAM_API_KEY not set")
        }
        
        var request = URLRequest(url: url)
        request.setValue("Token \(deepgramKey)", forHTTPHeaderField: "Authorization")
        
        socket = Starscream.WebSocket(request: request)
        socket.delegate = self
    }

    /// Connects to the active SpeechEngine and begins streaming audio
    func connect() async throws {
        guard !isActive else {
            throw SpeechServiceError.runtimeError("Already connected")
        }

        try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        installInputTapIfNeeded()

        if !audioEngine.isRunning {
            try audioEngine.start()
        }

        try await engine.start()

        isActive = true
    }

    /// Disconnect from the active SpeechEngine and deactivate microphone
    func disconnect() async {
        guard isActive else {
            logger.error("Already disconnected")
            return
        }

        logger.info("Disconnecting SpeechService...")
        isActive = false

        if hasInputTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInputTapInstalled = false
        }
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.reset()
        try? AVAudioSession.sharedInstance().setActive(false)

        await engine.stop()

        await assetWriter.finishWriting()

        if let error = assetWriter.error {
            await artifacts.logEvent(
                type: "SpeechService",
                message: "AssetWriter error: \(error.localizedDescription)"
            )
        } else {
            await artifacts.logEvent(
                type: "SpeechService",
                message: "Audio saved to \(conversationFileURL.lastPathComponent)"
            )

            if let anonymizer {
                do {
                    let outputURL = try await artifacts.getFileURL(name: outputName)
                    let finalURL = try await anonymizer.anonymize(
                        inputURL: conversationFileURL,
                        outputURL: outputURL
                    )
                    
                    // Log the success
                    await artifacts.logEvent(
                        type: "SpeechService",
                        message: "Anonymization complete: \(finalURL?.lastPathComponent ?? "unknown")"
                    )
                    
                    // Delete the original file now that we have the anonymized version
                    if finalURL != nil {
                        try FileManager.default.removeItem(at: conversationFileURL)
                        await artifacts.logEvent(
                            type: "SpeechService",
                            message: "Original file deleted: \(conversationFileURL.lastPathComponent)"
                        )
                    }
                    
                } catch {
                    await artifacts.logEvent(
                        type: "SpeechService",
                        message: "Anonymization failed: \(error.localizedDescription)"
                    )
                }
            } else {
                await artifacts.logEvent(
                    type: "SpeechService",
                    message: "No anonymizer configured — skipping"
                )
            }
        }

        logger.info("SpeechService stopped")
    }

    /// Reactivates the audio session and engine after the app returns to the foreground.
    /// No-ops if the service was intentionally disconnected.
    func reactivateIfNeeded() async {
        guard isActive else {
            await artifacts.logEvent(
                type: "SpeechService",
                message: "Skipping foreground restore because service is disconnected"
            )
            return
        }

        do {
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            if !audioEngine.isRunning {
                installInputTapIfNeeded()
                try audioEngine.start()
            }

            await artifacts.logEvent(
                type: "SpeechService",
                message: "Audio pipeline reactivated after app foreground"
            )
        } catch {
            await artifacts.logEvent(
                type: "SpeechService",
                message: "Failed to reactivate audio after app foreground: \(error.localizedDescription)"
            )
        }
    }
    
    /// Starscream WebSocket delegate method for handling connection, messages, and errors
    func didReceive(event: Starscream.WebSocketEvent, client: any Starscream.WebSocketClient) {
        Task {
            switch event {
            case .connected:
                isConnected = true
                await artifacts.logEvent(type: "Deepgram", message: "WebSocket connected")
            case .peerClosed:
                isConnected = false
                keepAliveTimer?.invalidate()
                keepAliveTimer = nil
                await artifacts.logEvent(type: "Deepgram", message: "WebSocket closed")
            case .cancelled:
                isConnected = false
                keepAliveTimer?.invalidate()
                keepAliveTimer = nil
                await artifacts.logEvent(type: "Deepgram", message: "WebSocket cancelled")
            case .disconnected(let reason, let code):
                isConnected = false
                keepAliveTimer?.invalidate()
                keepAliveTimer = nil
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
                let errorDescription: String
                if let error {
                    errorDescription = "\(error.localizedDescription) [\(String(describing: error))]"
                } else {
                    errorDescription = "unknown"
                }
                await artifacts.logEvent(
                    type: "Deepgram",
                    message: "WebSocket error: \(errorDescription)"
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

    private func startKeepAliveTimer() {
        keepAliveTimer?.invalidate()
        keepAliveTimer = Timer.scheduledTimer(
            withTimeInterval: 5.0,
            repeats: true
        ) { [weak self] _ in
            self?.sendKeepAlive()
        }
    }

    private func installInputTapIfNeeded() {
        guard !hasInputTapInstalled else { return }

        audioEngine.inputNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: audioFormat
        ) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer: buffer, time: time)
        }

        hasInputTapInstalled = true
    }

    /// Performs format conversions and sends audio data to the SpeechEngine and AssetWriter
    private func processAudioBuffer(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard isActive else { return }

        /// Send audio buffer to the active SpeechEngine for transcription
        engine.processAudioBuffer(buffer: buffer, time: time)

        /// Send audio buffer to asset writer (in native format)
        if let sampleBuffer = AudioBufferUtils.cmSampleBufferFromPCM(buffer) {
            if assetWriter.status == .unknown {
                let startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                if assetWriter.startWriting() {
                    assetWriter.startSession(atSourceTime: startTime)
                }
            }

            if assetWriter.status == .writing,
               assetWriterInput.isReadyForMoreMediaData {
                assetWriterInput.append(sampleBuffer)
            }
        }
    }

    /// Helper to handle the logging logic
    private func logChunk(_ chunk: TranscriptChunk) {
        let timeRange = String(format: "(%.1fs - %.1fs)", chunk.startAt, chunk.endAt)
        let status = chunk.isFinal ? "[FINAL]" : "[PARTIAL]"
        let speakerID = chunk.speakerID
        let logMessage = "\(timeRange) \(status) \(speakerID): \(chunk.text)"

        logger.info("\(logMessage)")

        // Only log to persistent artifacts if it's the final transcript
        if chunk.isFinal {
            Task {
                await artifacts.logEvent(type: "Transcript", message: logMessage)
            }
        }
    }
}
