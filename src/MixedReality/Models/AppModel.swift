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
    var isSessionActive = false
    
    var lastSessionError: String?

    // MARK: - Trigger / intervention pipeline
    private var triggerService = TriggerDemoService(useLLM: false)
    
    // MARK: - Prompt Generation
    // FIXME: code smells all over this
    private var promptGenerator: PromptGenerator!
    var prompt: String = ""

    // MARK: - Deepgram speech processor (created lazily)
    private var speechProcessor: SpeechProcessor?
    
    // MARK: - Artifact Collector
    private var artifactCollector: ArtifactCollector?
    func getArtifactCollector() -> ArtifactCollector {
        guard let ac = self.artifactCollector else { fatalError("ArtifactCollector not initialized") }
        return ac
    }
    
    init() {
        // 1) All stored properties above are initialized now.
        // 2) It is now safe to create PromptGenerator with self.
        self.promptGenerator = PromptGenerator(appModel: self)

        // 3) Wire trigger service callback after promptGenerator exists.
        triggerService.setOnEvent { [weak self] evt in
            guard let self else { return }
            self.getArtifactCollector().logEvent(type: "TriggerEngine", message: "(\(evt.id)) \(evt.reasonSummary)")
            Task {
                await self.promptGenerator.generate(evt: evt)
            }
        }
    }

    // MARK: - Session control
    func startSession() {
        guard !isSessionActive else { return }
        isSessionActive = true
        
        do {
            self.artifactCollector = try ArtifactCollector(id: "Session")
        } catch {
            isSessionActive = false
            lastSessionError = "Failed to start session storage: \(error.localizedDescription)"
            print("❌ Failed to create ArtifactCollector: \(error)")
            return
        }
        
        self.getArtifactCollector().logEvent(type: "AppModel", message: "Session started")
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
        triggerService.reset()
        prompt = ""
        self.getArtifactCollector().logEvent(type: "AppModel", message: "Session ended")
        self.getArtifactCollector().finalize()
        print("🛑 Session ended.")
    }

    // MARK: - Deepgram Delegate
    func speechProcessor(_ processor: SpeechProcessor,
                         didReceiveChunk chunk: DeepgramTranscriptChunk) {
        print("🎤 Deepgram → Engine: [\(chunk.speakerID)] \(chunk.text)")
        
        let start = String(format: "%.2f", chunk.start_time ?? 0)
        let end   = String(format: "%.2f", chunk.end_time ?? 0)
        
        if (chunk.isFinal ?? true) {
            self.getArtifactCollector().logEvent(
                type: "Transcript",
                message: "(\(start)-\(end)) \(chunk.speakerID): \"\(chunk.text)\""
            )
        }

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

