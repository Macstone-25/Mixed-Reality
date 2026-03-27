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
    var lastSessionId: String?
    var launchError: String?
    
    var activeScene: SceneID = SceneID.windowGroup
    var immersiveOpenRequest: UInt64 = 0
    
    var config = ConfigModel.load()
    
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
                lastSessionId = session?.id
            } catch {
                logger.error("❌ Failed to start session: \(error)")
                launchError = String(describing: error)
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

    func restoreSessionAfterForegrounding() {
        guard !isLaunchingSession, !isEndingSession, let session else { return }
        let currentSession = session

        logger.info("🪟 Restoring session after app foreground")

        if activeScene == .immersiveSpace {
            immersiveOpenRequest &+= 1
        } else {
            activeScene = .immersiveSpace
        }

        Task { [weak self] in
            guard let self else { return }
            guard !self.isEndingSession, self.session === currentSession else {
                self.logger.info("🔄 Skipping session restore after foreground because the session changed or is ending")
                return
            }
            await currentSession.restoreAfterForegrounding()
        }
    }
}
