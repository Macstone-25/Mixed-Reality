//
//  AppModel.swift
//  MixedReality (VisionOS Target)
//  Shared Deepgram → EventTrigger integration
//

import SwiftUI
import Foundation

@MainActor
@Observable
class AppModel {
    var session: SessionModel?
    var isEndingSession = false
    var isLaunchingSession = false
    var launchError: String?
    
    var config = ConfigModel()
    
    func startSession() {
        guard !isLaunchingSession && session == nil else { return }
        isLaunchingSession = true
        launchError = nil
        
        Task {
            do {
                session = try await SessionModel(config: config)
                print("🎧 Session started. Listening…")
                isLaunchingSession = false
            } catch {
                print("❌ Failed to start session: \(error)")
                launchError = error.localizedDescription
                isLaunchingSession = false
                return
            }
        }
    }

    func endSession() {
        guard !isEndingSession, let session = session else { return }
        isEndingSession = true
        
        Task {
            await session.end()
            self.session = nil
            print("🛑 Session ended.")
            isLaunchingSession = false
        }
    }
}

