import Foundation
import os

final class ArtifactCollector {
    private let logger = Logger(subsystem: "Session", category: "ArtifactCollector")
    
    private let rootFolder: URL
    private var handles: [FileHandle] = []
    private var finalized = false
    
    private lazy var eventsHandle: FileHandle = {
        do {
            return try getFileHandle(name: "Events.log")
        } catch {
            fatalError("Failed to create events handle: \(error)")
        }
    }()

    init(id: String) throws {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = getTimestamp()
        self.rootFolder = docs.appendingPathComponent("\(id)-\(timestamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootFolder, withIntermediateDirectories: true)
        logger.info("🗂️ Opened artifact collection at \(self.rootFolder.path())")
    }

    func getFileHandle(name: String) throws -> FileHandle {
        guard finalized == false else {
            throw NSError(domain: "ArtifactCollector", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot create file handle after artifact collection has been finalized"])
        }

        let fileId = handles.count
        let fileName = "\(fileId)-\(name)"

        let url = rootFolder.appendingPathComponent(fileName)
        logger.info("🗂️ Opening file handle for \(url.path)")
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }

        let handle = try FileHandle(forWritingTo: url)
        handles.append(handle)
        return handle
    }
    
    func getFileURL(name: String) throws -> URL {
        guard finalized == false else {
            throw NSError(
                domain: "ArtifactCollector",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey:
                    "Cannot create file URL after artifact collection has been finalized"]
            )
        }

        let fileId = handles.count
        let fileName = "\(fileId)-\(name)"
        let url = rootFolder.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        logger.info("🗂️ Provisioned artifact file URL \(url.path)")
        return url
    }


    func logEvent(type: String, message: String) {
        let timestamp = Int(Date().timeIntervalSince1970)
        let line = "(\(timestamp)) (\(type)) \(message)\n"
        let data = Data(line.utf8)

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
    
    deinit {
        finalize()
    }
}
