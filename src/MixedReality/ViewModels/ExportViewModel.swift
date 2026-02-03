//
//  ExportViewModel.swift
//  MixedReality
//

import Foundation
import Combine

struct SessionFolder: Identifiable {
    let id: URL
    var name: String
}

@MainActor
class ExportViewModel: ObservableObject {
    private let appModel: AppModel
    
    private var isRefreshing: Bool = false
    private var isExporting: Bool = false
    
    @Published var selection: Set<SessionFolder.ID> = []
    @Published var sessions: [SessionFolder] = []
    
    init(_ appModel: AppModel) {
        self.appModel = appModel
    }
    
    private var isBusy: Bool {
        isRefreshing || isExporting
    }
    
    var actionsDisabled: Bool {
        isBusy || selection.isEmpty
    }
    
    var selectionCount: String {
        "\(selection.count) \(selection.count == 1 ? "session" : "sessions")"
    }
    
    var statusText: String {
        if isRefreshing {
            "Finding sessions..."
        } else if sessions.isEmpty {
            "No session data available"
        } else if isExporting {
            "Exporting \(selectionCount) sessions..."
        } else {
            "\(selectionCount) selected"
        }
    }
    
    func refreshFolders() {
        guard !isBusy else { return }
        isRefreshing = true
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: documentsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            selection.removeAll()
            sessions.removeAll()
            isRefreshing = false
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
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        
        // Keep only selected IDs that still exist
        let validIDs = Set(newSessions.map(\.id))
        selection = selection.intersection(validIDs)
        sessions = newSessions
        
        isRefreshing = false
    }
    
    func selectAll() {
        if selection.count == sessions.count {
            selection.removeAll()
        } else {
            selection = Set(sessions.map(\.id))
        }
    }
    
    func exportData() {
        guard !isBusy else { return }
        isExporting = true
        
        
    }
}

