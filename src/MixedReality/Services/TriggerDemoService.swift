// TriggerDemoService.swift

import Foundation
import Combine

final class TriggerDemoService: ObservableObject {
    @Published var eventsLog: [InterventionEvent] = []

    private var engine: EventTriggerEngine
    private var bag = Set<AnyCancellable>()

    private(set) var primaryID: String        // exposed to the demo view
    private var llmEnabled: Bool
    
    private var onEvent: ((InterventionEvent) -> Void)?

    init(primaryID: String = "user", useLLM: Bool = false) {
        self.primaryID = primaryID
        self.llmEnabled = useLLM

        self.engine = EventTriggerEngine(
            primaryUserID: primaryID,
            silenceThreshold: 4.0,
            graceForOthers: 2.0,
            mode: useLLM ? .llmAugmented : .ruleBased,
            llm: useLLM ? HeuristicLLM() : nil,
            contextWindow: 30
        )

        attach()
    }

    private func attach() {
        bag.removeAll()

        engine.events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] evt in
                self?.eventsLog.append(evt)
                print("⚡️ Intervention @ \(evt.at) — \(evt.reasonSummary)")
                evt.context.forEach { c in
                    print("   [\(c.speakerID)] \(c.text)")
                }
                self?.onEvent?(evt)
            }
            .store(in: &bag)
    }

    // Allow updating the event callback after initialization
    func setOnEvent(_ handler: @escaping (InterventionEvent) -> Void) {
        self.onEvent = handler
    }

    // MARK: - Configuration

    func setUseLLM(_ enabled: Bool) {
        guard enabled != llmEnabled else { return }
        llmEnabled = enabled
        let evaluator: LLMEvaluator? = enabled ? HeuristicLLM() : nil
        engine.updateLLMMode(enabled: enabled, llm: evaluator)
        // eventsLog is *not* touched here – history stays, engine state preserved
    }

    func setPrimaryUserID(_ id: String) {
        guard id != primaryID else { return }
        primaryID = id
        engine.updatePrimaryUserID(id)
        // again, we keep buffer + pause state; only who we monitor changes
    }

    func reset() {
        engine.reset()
        eventsLog.removeAll()
    }

    // MARK: - Public API (used by AppModel / Deepgram)

    /// Feed a real ASR chunk into the trigger engine.
    func receive(_ chunk: TranscriptChunk) {
        engine.receive(chunk)
    }

    // MARK: - Sim inputs for the demo UI

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
