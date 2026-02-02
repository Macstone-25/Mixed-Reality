//
//  AppModel.swift
//  MixedReality (VisionOS Target)
//  Shared Deepgram → EventTrigger integration
//

import SwiftUI
import Foundation

enum SceneID: String {
    case immersiveSpace = "ImmersiveSpace"
    case windowGroup = "DefaultWindowGroup"
}

@MainActor
@Observable
class AppModel {
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
                print("🎧 Session started. Launching immersive space…")
                activeScene = SceneID.immersiveSpace
            } catch {
                print("❌ Failed to start session: \(error)")
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
            print("🛑 Session ended.")
            activeScene = SceneID.windowGroup
            isEndingSession = false
        }
    }
}

