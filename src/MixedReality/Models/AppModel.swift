//
//  AppModel.swift
//  MixedReality (VisionOS Target)
//  Shared Deepgram → EventTrigger integration
//

import SwiftUI
import Foundation
import OSLog

enum SceneID: String {
    case immersiveSpace = "ImmersiveSpace"
    case windowGroup = "DefaultWindowGroup"
}

@MainActor
@Observable
class AppModel {
    let logger = Logger()
    
    var session: SessionModel?
    var isEndingSession = false
    var isLaunchingSession = false
    var launchError: String?
    
    var activeScene: SceneID = SceneID.windowGroup
    
    var config = ConfigModel.load()
    
    func startSession() {
        guard !isLaunchingSession && session == nil else { return }
        isLaunchingSession = true
        launchError = nil
        
        let config = config
        
        Task.detached { [weak self] in
            let newSession: SessionModel
            do {
                newSession = try await SessionModel(config: config)
                try await newSession.start()
            } catch {
                return await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.logger.error("❌ Failed to start session: \(error)")
                    self.launchError = error.localizedDescription
                    self.isLaunchingSession = false
                }
            }
            
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.session = newSession
                self.logger.info("🎧 Session started. Launching immersive space…")
                self.activeScene = SceneID.immersiveSpace
                self.isLaunchingSession = false
            }
        }
    }

    func endSession() {
        guard !isEndingSession, let session = session else { return }
        isEndingSession = true
        Task.detached { [weak self] in
            await session.end()
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.session = nil
                self.logger.info("🛑 Session ended")
                self.activeScene = SceneID.windowGroup
                self.isEndingSession = false
            }
        }
    }
}

