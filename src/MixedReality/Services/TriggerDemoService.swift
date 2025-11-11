// TriggerDemoService.swift
//
// Demo service that wraps EventTriggerEngine, lets the UI simulate ASR input,
// toggle the LLM gate, and switch which diarized speaker is treated as “primary”.

import Foundation
import Combine

final class TriggerDemoService: ObservableObject {
    // Logs shown in the demo UI
    @Published var eventsLog: [InterventionEvent] = []

    // Current primary speaker label (the one we monitor for pauses)
    @Published private(set) var primaryID: String

    // Internals
    private var engine: EventTriggerEngine
    private var bag = Set<AnyCancellable>()
    private var llmEnabled: Bool

    init(primaryID: String = "user", useLLM: Bool = false) {
        self.primaryID = primaryID
        self.llmEnabled = useLLM
        self.engine = EventTriggerEngine(
            primaryUserID: primaryID,
            silenceThreshold: 4.0,      // tweak to taste
            graceForOthers: 2.0,        // extra time when others speak after the user
            mode: useLLM ? .llmAugmented : .ruleBased,
            llm: useLLM ? HeuristicLLM() : nil,
            contextWindow: 8
        )
        attach()
    }

    // Subscribe to engine events
    private func attach() {
        bag.removeAll()
        engine.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] evt in
                self?.eventsLog.append(evt)
                // Debug print for console
                print("⚡️ Intervention @ \(evt.at) — \(evt.reasonSummary)")
                evt.context.forEach { c in print("   [\(c.speakerID)] \(c.text)") }
            }
            .store(in: &bag)
    }

    // Toggle LLM layer on/off without replacing the @StateObject from the view
    func setUseLLM(_ enabled: Bool) {
        guard enabled != llmEnabled else { return }
        llmEnabled = enabled

        let oldLog = eventsLog
        engine = EventTriggerEngine(
            primaryUserID: primaryID,
            silenceThreshold: 4.0,
            graceForOthers: 2.0,
            mode: enabled ? .llmAugmented : .ruleBased,
            llm: enabled ? HeuristicLLM() : nil,
            contextWindow: 8
        )
        attach()
        eventsLog = oldLog
    }

    // Change which diarized speaker we treat as the primary user
    func setPrimaryUserID(_ id: String) {
        guard id != primaryID else { return }
        primaryID = id

        let oldLog = eventsLog
        engine = EventTriggerEngine(
            primaryUserID: id,
            silenceThreshold: 4.0,
            graceForOthers: 2.0,
            mode: llmEnabled ? .llmAugmented : .ruleBased,
            llm: llmEnabled ? HeuristicLLM() : nil,
            contextWindow: 8
        )
        attach()
        eventsLog = oldLog
    }

    // Reset demo state
    func reset() {
        engine.reset()
        eventsLog.removeAll()
    }

    // MARK: - Simulated ASR input

    func userSays(_ text: String) {
        feed(text: text, speaker: primaryID)
    }

    func otherSays(_ text: String, id: String = "spk_1") {
        feed(text: text, speaker: id)
    }

    private func feed(text: String, speaker: String) {
        let now = Date()
        let chunk = TranscriptChunk(
            text: text,
            speakerID: speaker,
            isFinal: true,
            startAt: now.addingTimeInterval(-0.8),
            endAt: now
        )
        engine.receive(chunk)
    }
}
