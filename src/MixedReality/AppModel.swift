//
//  AppModel.swift
//  MixedReality (VisionOS Target)
//  Shared Deepgram → EventTrigger integration
//

import SwiftUI
import Foundation

@MainActor
@Observable
class AppModel: SpeechProcessorDelegate {

    // MARK: - VisionOS Scene identifiers
    let immersiveSpaceId = "ImmersiveSpace"
    let windowGroupId = "DefaultWindowGroup"

    // MARK: - State
    var hasConsent = false
    var isSessionActive = false

    // MARK: - Auto primary detection
    var primarySpeakerID: String = "user"

    // MARK: - Trigger / intervention pipeline
    let triggerService = TriggerDemoService(useLLM: false)

    // MARK: - Deepgram speech processor (created lazily)
    private var speechProcessor: SpeechProcessor?

    // MARK: - Session control
    func startSession() {
        guard !isSessionActive else { return }
        isSessionActive = true
        print("🎧 Session started. Listening…")

        // Lazily create processor the first time we start a session
        if speechProcessor == nil {
            let sp = SpeechProcessor()
            sp.delegate = self
            speechProcessor = sp
        }
    }

    func endSession() {
        guard isSessionActive else { return }
        isSessionActive = false
        speechProcessor?.deconfigureAudioEngine()
        speechProcessor = nil
        print("🛑 Session ended.")
    }

    // MARK: - Deepgram Delegate
    func speechProcessor(_ processor: SpeechProcessor,
                         didReceiveChunk chunk: DeepgramTranscriptChunk) {

        print("🎤 Deepgram → Engine: [\(chunk.speakerID)] \(chunk.text)")

        // ✅ Auto-select first speaker as primary
        if primarySpeakerID == "user" {
            print("🔑 Auto-selected primary speaker: \(chunk.speakerID)")
            primarySpeakerID = chunk.speakerID
            triggerService.setPrimaryUserID(chunk.speakerID)
        }

        // ✅ Convert Deepgram chunk → engine chunk
        let engineChunk = TranscriptChunk(from: chunk)

        // ✅ Feed into EventTriggerEngine
        triggerService.receive(engineChunk)
    }
}
