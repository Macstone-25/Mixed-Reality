//
//  SpeechService.swift
//  MixedReality
//

import Foundation
import Combine
import AVFoundation
import OSLog

enum SpeechServiceError: Error {
    case configError(String)
    case apiError(String)
    case runtimeError(String)
    case permissionError(String)
}

class SpeechService {
    private let logger = Logger(subsystem: "SpeechService", category: "Services")
    private static let inputTapBufferSize: AVAudioFrameCount = 2048

    private let artifacts: ArtifactService
    private let experiment: ExperimentModel
    private let anonymizer: (any AudioAnonymizer)?
    private let capture: any AudioCapture

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

    private let conversationFileURL: URL
    private let outputName: String

    init(
        engine: any SpeechEngine,
        artifacts: ArtifactService,
        experiment: ExperimentModel,
        anonymizer: (any AudioAnonymizer)? = nil,
        capture: any AudioCapture = LiveAudioCapture()
    ) async throws {
        self.engine = engine
        self.artifacts = artifacts
        self.experiment = experiment
        self.anonymizer = anonymizer
        self.capture = capture

        /// Configure audio session
        let isPermissionGranted = await capture.requestPermission()
        guard isPermissionGranted else {
            throw SpeechServiceError.permissionError("Recording permission was not granted")
        }

        try capture.activateSession()

        let audioFormat = capture.inputFormat
        guard audioFormat.channelCount > 0, audioFormat.sampleRate > 0 else {
            throw SpeechServiceError.runtimeError(
                "Invalid input format — channels: \(audioFormat.channelCount), sample rate: \(audioFormat.sampleRate)"
            )
        }

        /// Create AssetWriter
        let fileURL = try await artifacts.getFileURL(name: "Conversation.m4a")
        self.conversationFileURL = fileURL
        self.outputName = "Anonymized_Conversation.m4a"

        try capture.startRecording(to: fileURL)
    }

    /// Connects to the active SpeechEngine and begins streaming audio
    func connect() async throws {
        guard !isActive else {
            throw SpeechServiceError.runtimeError("Already connected")
        }

        try capture.activateSession()
        installInputTapIfNeeded()

        if !capture.isEngineRunning {
            try capture.startEngine()
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
            capture.removeTap()
            hasInputTapInstalled = false
        }
        if capture.isEngineRunning { capture.stopEngine() }
        capture.resetEngine()
        try? capture.deactivateSession()

        await engine.stop()

        await capture.stopRecording()

        if let error = capture.recordingError {
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
            try capture.activateSession()
            if !capture.isEngineRunning {
                installInputTapIfNeeded()
                try capture.startEngine()
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

        try? capture.installTap(bufferSize: Self.inputTapBufferSize) { [weak self] buffer, time in
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
            capture.append(sampleBuffer)
        }
    }

    /// Helper to handle the logging logic
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
