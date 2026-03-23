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
    private var hasInputTapInstalled = false

    private let audioEngine = AVAudioEngine()
    private let audioFormat: AVAudioFormat
    private let audioBootstrapper: AudioSessionBootstrapping

    private let assetWriter: AVAssetWriter
    private let assetWriterInput: AVAssetWriterInput
    private let conversationFileURL: URL
    private let outputName: String

    init(
        engine: SpeechEngines,
        artifacts: ArtifactService,
        experiment: ExperimentModel,
        anonymizer: (any AudioAnonymizer)? = nil,
        audioBootstrapper: AudioSessionBootstrapping
    ) async throws {
        self.artifacts = artifacts
        self.experiment = experiment
        self.anonymizer = anonymizer
        self.audioBootstrapper = audioBootstrapper

        let preferredSampleRate = DeepgramConfig().preferredSampleRate
        self.audioFormat = try await audioBootstrapper.resolveInputFormat(
            for: audioEngine.inputNode,
            preferredSampleRate: preferredSampleRate
        )

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

        let fileURL = try await artifacts.getFileURL(name: "Conversation.m4a")
        self.conversationFileURL = fileURL
        self.outputName = "Anonymized_Conversation.m4a"

        assetWriter = try AVAssetWriter(outputURL: fileURL, fileType: .m4a)

        let sampleRate = audioFormat.sampleRate
        let safeSampleRate: Double = (sampleRate == 44_100 || sampleRate == 48_000) ? sampleRate : 48_000

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
        guard !isActive else {
            throw SpeechServiceError.runtimeError("Already connected")
        }

        // Re-activate the already prewarmed session before installing the input tap.
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

                    await artifacts.logEvent(
                        type: "SpeechService",
                        message: "Anonymization complete: \(finalURL?.lastPathComponent ?? "unknown")"
                    )

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

        engine.processAudioBuffer(buffer: buffer, time: time)

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

    private func logChunk(_ chunk: TranscriptChunk) {
        let timeRange = String(format: "(%.1fs - %.1fs)", chunk.startAt, chunk.endAt)
        let status = chunk.isFinal ? "[FINAL]" : "[PARTIAL]"
        let speakerID = chunk.speakerID
        let logMessage = "\(timeRange) \(status) \(speakerID): \(chunk.text)"

        logger.info("\(logMessage)")

        if chunk.isFinal {
            Task {
                await artifacts.logEvent(type: "Transcript", message: logMessage)
            }
        }
    }
}
