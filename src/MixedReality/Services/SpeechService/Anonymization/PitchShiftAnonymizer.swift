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

    init(
        semitones: Float
    ) {
        self.semitones = semitones
    }

    func anonymize(inputURL: URL, outputURL: URL) async throws -> URL? {
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

        logger.info("Anonymized audio written to \(outputURL.lastPathComponent)")

        return outputURL
    }
}
