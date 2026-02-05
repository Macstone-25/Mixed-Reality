//
//  PromptViewModel.swift
//  MixedReality
//

import Foundation

@MainActor
@Observable
class PromptViewModel {
    private let appModel: AppModel
    private let sessionViewModel: SessionViewModel
    
    private var gazeTimer: Timer?
    private var gazeProgressTimer: Timer?
    private var gazeStartAt: Date?
    
    // Gaze dwell threshold in seconds
    private let gazeThreshold: TimeInterval = 2.5
    
    // 0.0 → 1.0 progress for dwell indicator
    var gazeProgress: Double = 0.0
    
    // Combined gaze signals
    private var isFocused: Bool = false
    private var isHovering: Bool = false
    
    var isGazeActive: Bool {
        isFocused || isHovering
    }
    
    init(appModel: AppModel, sessionViewModel: SessionViewModel) {
        self.appModel = appModel
        self.sessionViewModel = sessionViewModel
    }
    
    var isVisible: Bool {
        !sessionViewModel.prompt.isEmpty
    }
    
    // MARK: - Gaze Signal
    
    func updateGazeSignal(isFocused: Bool? = nil, isHovering: Bool? = nil) {
        if let isFocused = isFocused { self.isFocused = isFocused }
        if let isHovering = isHovering { self.isHovering = isHovering }
        
        if isGazeActive {
            startGazeTimer()
        } else {
            cancelGazeTimer()
        }
    }
    
    // MARK: - Gaze Timer
    
    func startGazeTimer() {
        // Don't start if already read or no prompt
        guard !sessionViewModel.hasPromptBeenRead(), !sessionViewModel.prompt.isEmpty else { return }
        
        if gazeTimer != nil { return } // already running
        
        gazeProgressTimer?.invalidate()
        gazeStartAt = Date()
        gazeProgress = 0.0
        
        gazeProgressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let elapsed = Date().timeIntervalSince(self.gazeStartAt ?? Date())
            let progress = min(max(elapsed / self.gazeThreshold, 0), 1)
            self.gazeProgress = progress
        }
        
        gazeTimer = Timer.scheduledTimer(withTimeInterval: gazeThreshold, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.markAsReadViaGaze()
            }
        }
    }
    
    func cancelGazeTimer() {
        gazeTimer?.invalidate()
        gazeTimer = nil
        gazeProgressTimer?.invalidate()
        gazeProgressTimer = nil
        gazeStartAt = nil
        gazeProgress = 0.0
    }
    
    private func markAsReadViaGaze() {
        sessionViewModel.logPromptRead(method: .gaze)
        gazeProgress = 1.0
        gazeProgressTimer?.invalidate()
        gazeProgressTimer = nil
    }
    
    func confirmReadAndClear() {
        // Log as button read if not already read via gaze
        if !sessionViewModel.hasPromptBeenRead() {
            sessionViewModel.logPromptRead(method: .button)
        }
        cancelGazeTimer()
        sessionViewModel.clearPrompt()
    }
    
    func onPromptChanged() {
        // Reset gaze state whenever prompt changes
        cancelGazeTimer()
    }
}
