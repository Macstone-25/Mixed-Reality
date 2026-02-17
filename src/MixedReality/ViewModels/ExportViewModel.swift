//
//  ExportViewModel.swift
//  MixedReality
//

import Foundation
import Combine
import OSLog

struct SessionFolder: Identifiable {
    let id: URL
    var name: String
}

@MainActor
class ExportViewModel: ObservableObject {
    private let appModel: AppModel
    
    @Published var sessions: [SessionFolder] = []
    @Published var selection: Set<SessionFolder.ID> = []
    @Published var isRefreshing: Bool = false
    
    @Published var isExporting: Bool = false
    @Published var zipURL: URL? = nil
    private var exportError: String? = nil
    
    init(_ appModel: AppModel) {
        self.appModel = appModel
    }
    
    var isBusy: Bool {
        isRefreshing || isExporting
    }
    
    var actionsDisabled: Bool {
        isBusy || selection.isEmpty
    }
    
    var selectionCount: String {
        "\(selection.count) \(selection.count == 1 ? "session" : "sessions")"
    }
    
    var statusText: String {
        if let error = exportError {
            error
        } else if isRefreshing {
            "Finding sessions..."
        } else if sessions.isEmpty {
            "No session data available"
        } else if isExporting {
            "Exporting \(selectionCount)..."
        } else {
            "\(selectionCount) selected"
        }
    }
    
    func refreshFolders() {
        guard !isBusy else { return }
        isRefreshing = true
        
        Task.detached { [weak self] in
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: documentsURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.selection.removeAll()
                    self.sessions.removeAll()
                    self.isRefreshing = false
                }
                return
            }
            
            let newSessions = contents
                .filter { url in
                    (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                }
                .map { url in
                    SessionFolder(id: url, name: url.lastPathComponent)
                }
                .sorted {
                    $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending
                }
            
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                // Keep only selected IDs that still exist
                let validIDs = Set(newSessions.map(\.id))
                self.selection = self.selection.intersection(validIDs)
                self.sessions = newSessions
                self.isRefreshing = false
            }
        }
    }
    
    func selectAll() {
        if selection.count == sessions.count {
            selection.removeAll()
        } else {
            selection = Set(sessions.map(\.id))
        }
    }
    
    func deleteData() {
        guard !isBusy && appModel.config.isDeleteEnabled else { return }
        isExporting = true
        exportError = nil
        
        let fm = FileManager.default
        let selection = selection
        
        Task.detached { [weak self] in
            do {
                for src in selection {
                    var isDir: ObjCBool = false
                    guard fm.fileExists(atPath: src.path, isDirectory: &isDir), isDir.boolValue else {
                        continue
                    }
                    try fm.removeItem(at: src)
                }
                
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.appModel.logger.info("Deleted \(selection.count) sessions")
                    self.isExporting = false
                    self.refreshFolders()
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    let errorMessage = "Failed to delete session data: \(error.localizedDescription)"
                    self.appModel.logger.error("\(errorMessage, privacy: .public)")
                    self.exportError = errorMessage
                    self.isExporting = false
                }
            }
        }
    }
    
    func exportData() {
        guard !isBusy else { return }
        isExporting = true
        exportError = nil
        
        let fm = FileManager.default
        let selection = selection

        Task.detached { [weak self] in
            do {
                let timestamp = ArtifactService.makeTimestamp()
                let exportName = "Export-\(timestamp)"
                
                // Create a unique working directory in tmp
                let workingDir = fm.temporaryDirectory
                    .appendingPathComponent(exportName, isDirectory: true)
                try fm.createDirectory(at: workingDir, withIntermediateDirectories: true)
                
                // Copy each source folder into the working directory
                for src in selection {
                    var isDir: ObjCBool = false
                    guard fm.fileExists(atPath: src.path, isDirectory: &isDir), isDir.boolValue else {
                        continue
                    }
                    let dest = workingDir.appendingPathComponent(src.lastPathComponent, isDirectory: true)
                    try fm.copyItem(at: src, to: dest)
                }
                
                // Zip the working directory
                let coordinator = NSFileCoordinator()
                var coordError: NSError?
                var copyError: Error?
                
                let outZipURL = fm.temporaryDirectory
                    .appendingPathComponent("\(exportName).zip", isDirectory: false)
                
                coordinator.coordinate(readingItemAt: workingDir,
                                       options: .forUploading,
                                       error: &coordError) { zippedSnapshotURL in
                    do {
                        if fm.fileExists(atPath: outZipURL.path) {
                            try fm.removeItem(at: outZipURL)
                        }
                        try fm.copyItem(at: zippedSnapshotURL, to: outZipURL)
                    } catch {
                        copyError = error
                    }
                }
                
                if let coordError { throw coordError }
                if let copyError { throw copyError }
                
                // Clean up the working directory
                try? fm.removeItem(at: workingDir)
                
                // Prompt the user to download / share the .zip
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.zipURL = outZipURL
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    let errorMessage = "Failed to zip session data: \(error.localizedDescription)"
                    self.appModel.logger.error("\(errorMessage, privacy: .public)")
                    self.exportError = errorMessage
                    self.isExporting = false
                }
            }
        }
    }
    
    func cleanup() {
        if let zipURL = zipURL {
            Task.detached { try? FileManager.default.removeItem(at: zipURL) }
        }
        zipURL = nil
        isExporting = false
    }
}

