//
//  SessionControlsViewModel.swift
//  MixedReality
//

import Foundation

@MainActor
@Observable
class SessionControlsViewModel {
    private let appModel: AppModel
    private let sessionViewModel: SessionViewModel
    
    private var elapsedTime: TimeInterval = 0
    private var timer: Timer?
    
    init(appModel: AppModel, sessionViewModel: SessionViewModel) {
        self.appModel = appModel
        self.sessionViewModel = sessionViewModel
    }
    
    var isVisible: Bool {
        !appModel.isLaunchingSession && appModel.session != nil
    }
    
    var timeString: String {
        let seconds = Int(elapsedTime) % 60
        let minutes = (Int(elapsedTime) / 60) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func onAppear() {
        timer?.invalidate()
        elapsedTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.elapsedTime += 1
            }
        }
    }
    
    func onStop() {
        timer?.invalidate()
        timer = nil
        
        appModel.session?.onPrompt = nil
        sessionViewModel.prompt = ""
        
        appModel.endSession()
    }
}
