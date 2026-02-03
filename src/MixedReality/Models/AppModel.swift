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
    
    var config = ConfigModel()
    
    func startSession() {
        guard !isLaunchingSession && session == nil else { return }
        isLaunchingSession = true
        launchError = nil
        
        Task {
            do {
                session = try await SessionModel(config: config)
                try await session?.start()
                logger.info("🎧 Session started. Launching immersive space…")
                activeScene = SceneID.immersiveSpace
            } catch {
                logger.error("❌ Failed to start session: \(error)")
                launchError = error.localizedDescription
            }
            isLaunchingSession = false
        }
    }

    func endSession() {
        guard !isEndingSession, let session = session else { return }
        isEndingSession = true
        
        Task {
            await session.end()
            self.session = nil
            logger.info("🛑 Session ended")
            activeScene = SceneID.windowGroup
            isEndingSession = false
        }
    }
}

