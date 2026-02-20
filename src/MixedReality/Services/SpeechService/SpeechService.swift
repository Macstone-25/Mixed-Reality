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
        engine.transcriptChunkEvent.eraseToAnyPublisher()
    }

    private let engine: SpeechEngine

    private var isConnected = false

    private let audioEngine = AVAudioEngine()
    private let audioFormat: AVAudioFormat

    private let assetWriter: AVAssetWriter
    private let assetWriterInput: AVAssetWriterInput
    private let conversationFileURL: URL

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
    }

    /// Connects to the active SpeechEngine and begins streaming audio
    func connect() async throws {
        guard !isConnected else {
            throw SpeechServiceError.runtimeError("Already connected")
        }

        try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)

        audioEngine.inputNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: audioFormat
        ) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer: buffer, time: time)
        }

        try audioEngine.start()
        try await engine.start()

        isConnected = true
    }

    /// Disconnect from the active SpeechEngine and deactivate microphone
    func disconnect() async {
        guard isConnected else {
            logger.error("Already disconnected")
            return
        }

        logger.info("Disconnecting SpeechService...")
        isConnected = false

        audioEngine.inputNode.removeTap(onBus: 0)
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
                    let outputURL = try await anonymizer.anonymize(
                        inputURL: conversationFileURL,
                        artifacts: artifacts
                    )
                    await artifacts.logEvent(
                        type: "SpeechService",
                        message: "Anonymization complete: \(outputURL?.lastPathComponent)"
                    )
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

    /// Performs format conversions and sends audio data to the SpeechEngine and AssetWriter
    private func processAudioBuffer(buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard isConnected else { return }

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
}
