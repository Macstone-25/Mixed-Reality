//
//  AppModelCore.swift
//  Shared logic for Deepgram → TriggerEngine
//

import Foundation

class AppModelCore: SpeechProcessorDelegate {

    // MARK: - Session State
    var isSessionActive = false

    // Auto-selected primary user
    var primarySpeakerID: String = "user"

    // Trigger engine
    let triggerService: TriggerDemoService

    // Deepgram processor
    lazy var speechProcessor: SpeechProcessor = {
        let sp = SpeechProcessor()
        sp.delegate = self
        return sp
    }()

    init(primary: String = "user", useLLM: Bool = false) {
        self.primarySpeakerID = primary
        self.triggerService = TriggerDemoService(primaryID: primary, useLLM: useLLM)
    }

    func startSession() {
        isSessionActive = true
        _ = speechProcessor         // boot microphone
        print("🎧 Session started. Listening…")
    }

    func endSession() {
        isSessionActive = false
        speechProcessor.deconfigureAudioEngine()
        print("🛑 Session ended.")
    }

    // MARK: - Deepgram delegate
    func speechProcessor(_ processor: SpeechProcessor,
                         didReceiveChunk chunk: DeepgramTranscriptChunk) {

        print("🎤 Deepgram → Engine: [\(chunk.speakerID)] \(chunk.text)")

        // Auto primary speaker selection
        if primarySpeakerID == "user" {
            print("🔑 Auto-selected primary speaker: \(chunk.speakerID)")
            primarySpeakerID = chunk.speakerID
            triggerService.setPrimaryUserID(chunk.speakerID)
        }

        let engineChunk = TranscriptChunk(from: chunk)

        triggerService.receive(engineChunk)
    }
}
