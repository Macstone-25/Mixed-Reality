import AVFoundation
import Foundation
import os

enum ArtifactServiceError : Error {
    case useAfterFinalized(String)
}

final actor ArtifactService {
    private let logger = Logger(subsystem: "ArtifactService", category: "Services")
    
    private let rootFolder: URL
    private var handles: [FileHandle] = []
    private var finalized = false
    private var id = 0
    
    private lazy var eventsHandle: FileHandle = {
        do {
            return try getFileHandle(name: "Events.log")
        } catch {
            fatalError("Failed to create events handle: \(error)")
        }
    }()

    init(id: String) throws {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Self.makeTimestamp()
        self.rootFolder = docs.appendingPathComponent("\(id)-\(timestamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootFolder, withIntermediateDirectories: true)
        logger.info("🗂️ Opened artifact collection at \(self.rootFolder.path())")
    }
    
    private func nextId() -> Int {
        defer { self.id += 1 }
        return self.id
    }

    func getFileURL(name: String) throws -> URL {
        guard finalized == false else {
            throw ArtifactServiceError.useAfterFinalized("Cannot create artifacts after artifact collection has been finalized")
        }

        let fileId = nextId()
        let fileName = "\(fileId)-\(name)"
        let url = rootFolder.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        logger.info("🗂️ Provisioned artifact file path \(url.path)")
        return url
    }

    func getFileHandle(name: String) throws -> FileHandle {
        let url = try getFileURL(name: name)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        handles.append(handle)
        return handle
    }

    func logEvent(type: String, message: String) {
        let timestamp = Int(Date().timeIntervalSince1970)
        let line = "(\(timestamp)) (\(type)) \(message)\n"
        let data = Data(line.utf8)
        
        guard finalized == false else {
            logger.error("⛔️ Tried to log event after finalization: \(line)")
            return
        }

        do {
            try eventsHandle.seekToEnd()
            try eventsHandle.write(contentsOf: data)
            logger.info("✍️ \(line)")
        } catch {
            logger.error("⛔️ Failed to log event: \(line)\(error)")
        }
    }

    func finalize() {
        guard finalized == false else { return }
        finalized = true

        for handle in handles {
            do {
                try handle.close()
            } catch {
                logger.warning("⚠️ Failed to close handle: \(error)")
            }
        }

        handles.removeAll()
        logger.info("🗂️ Closed artifact collection at \(self.rootFolder.path())")
    }
    
    private func pitchShiftFile(
        inputURL: URL,
        outputURL: URL,
        semitones: Float
    ) throws {
        let inputFile = try AVAudioFile(forReading: inputURL)
        let format = inputFile.processingFormat

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let pitch = AVAudioUnitTimePitch()

        pitch.pitch = semitones * 100 // cents

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

        player.scheduleFile(inputFile, at: nil)
        player.play()

        let buffer = AVAudioPCMBuffer(
            pcmFormat: engine.manualRenderingFormat,
            frameCapacity: engine.manualRenderingMaximumFrameCount
        )!

        while engine.manualRenderingSampleTime < inputFile.length {
            let status = try engine.renderOffline(
                buffer.frameCapacity,
                to: buffer
            )

            if status == .success {
                try outputFile.write(from: buffer)
            }
        }

        engine.stop()
    }
    
    func anonymizeAudioFile(
        inputURL: URL,
        outputName: String = "conversation_anonymized.m4a",
        pitchSemitones: Float = 3.0,
        deleteOriginal: Bool = true
    ) throws -> URL {
        guard finalized == false else {
            throw NSError(
                domain: "ArtifactCollector",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey:
                    "Cannot anonymize artifacts after collection has been finalized"]
            )
        }

        let outputURL = try getFileURL(name: outputName)

        try pitchShiftFile(
            inputURL: inputURL,
            outputURL: outputURL,
            semitones: pitchSemitones
        )

        if deleteOriginal {
            try? FileManager.default.removeItem(at: inputURL)
            logger.info("Deleted original audio file after anonymization")
        }

        logger.info("Anonymized audio written to \(outputURL.lastPathComponent)")
        return outputURL
    }


    
    // Local, non-main-actor timestamp generator to avoid calling main-actor-isolated utilities here.
    private static func makeTimestamp() -> String {
        // ISO 8601-like compact timestamp: yyyyMMdd-HHmmss
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: now)
        let y = comps.year ?? 0
        let M = comps.month ?? 0
        let d = comps.day ?? 0
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        let s = comps.second ?? 0
        return String(format: "%04d%02d%02d-%02dh%02dm%02ds", y, M, d, h, m, s)
    }
}
