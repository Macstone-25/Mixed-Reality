//
//  PitchShiftAnonymizer.swift
//  MixedReality
//

import Foundation
import AVFoundation
import OSLog

class PitchShiftAnonymizer: AudioAnonymizer {
    private let logger = Logger(subsystem: "PitchShiftAnonymizer", category: "Services")

    private let semitones: Float
    private let deleteOriginal: Bool
    private let outputName: String

    init(
        semitones: Float,
        deleteOriginal: Bool = false,
        outputName: String = "Conversation_Anonymized.m4a"
    ) {
        self.semitones = semitones
        self.deleteOriginal = deleteOriginal
        self.outputName = outputName
    }

    func anonymize(inputURL: URL, artifacts: ArtifactService) async throws -> URL? {
        let outputURL = try await artifacts.getFileURL(name: outputName)

        let inputFile = try AVAudioFile(forReading: inputURL)
        let format = inputFile.processingFormat

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let pitch = AVAudioUnitTimePitch()

        pitch.pitch = semitones * 100 // AVAudioUnitTimePitch works in cents

        engine.attach(player)
        engine.attach(pitch)
        engine.connect(player, to: pitch, format: format)
        engine.connect(pitch, to: engine.mainMixerNode, format: format)

        try engine.enableManualRenderingMode(
            .offline,
            format: format,
            maximumFrameCount: 4096
        )

        try engine.start()

        let outputFile = try AVAudioFile(
            forWriting: outputURL,
            settings: inputFile.fileFormat.settings
        )

        player.scheduleFile(inputFile, at: nil, completionHandler: nil)
        player.play()

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: engine.manualRenderingFormat,
            frameCapacity: engine.manualRenderingMaximumFrameCount
        ) else {
            logger.error("Issue initializing PCM Buffer.")
            return nil
        }

        while engine.manualRenderingSampleTime < inputFile.length {
            let status = try engine.renderOffline(buffer.frameCapacity, to: buffer)
            if status == .success {
                try outputFile.write(from: buffer)
            }
        }

        engine.stop()
        engine.reset()

        if deleteOriginal {
            try? FileManager.default.removeItem(at: inputURL)
            logger.info("Deleted original audio after anonymization")
        }

        logger.info("Anonymized audio written to \(outputURL.lastPathComponent)")

        await artifacts.logEvent(
            type: "PitchShiftAnonymizer",
            message: "Anonymized audio created: \(outputURL.lastPathComponent)"
        )

        return outputURL
    }
}
