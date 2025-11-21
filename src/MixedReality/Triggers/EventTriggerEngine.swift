// EventTriggerEngine.swift

import Foundation
import Combine

public final class EventTriggerEngine: InterventionTriggering {
    // MARK: - Modes
    public enum Mode { case ruleBased, llmAugmented }

    // MARK: - Dependencies / config
    private var primaryUserID: String          // <-- var
    private var mode: Mode                     // <-- var
    private var llm: LLMEvaluator?             // <-- var
    private let rule: PauseRuleTrigger

    // MARK: - Context buffer
    private let contextWindow: Int
    private var buffer: [TranscriptChunk] = []
    private let bufferQueue = DispatchQueue(label: "EventTriggerEngine.buffer")

    // MARK: - Outputs
    private let eventsSubject = PassthroughSubject<InterventionEvent, Never>()
    public var events: AnyPublisher<InterventionEvent, Never> {
        eventsSubject.eraseToAnyPublisher()
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    public init(
        primaryUserID: String,
        silenceThreshold: TimeInterval = 4.0,
        graceForOthers: TimeInterval = 2.0,
        mode: Mode = .ruleBased,
        llm: LLMEvaluator? = nil,
        contextWindow: Int = 8
    ) {
        // Validate & normalise primary ID so we never end up with an "invisible" primary user.
        let trimmedID = primaryUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        precondition(
            !trimmedID.isEmpty,
            "primaryUserID must be non-empty and not just whitespace"
        )

        self.primaryUserID = trimmedID
        self.mode = mode
        self.llm = llm
        self.contextWindow = max(1, contextWindow)
        self.rule = PauseRuleTrigger(
            primaryUserID: trimmedID,
            silenceThreshold: silenceThreshold,
            graceForOthers: graceForOthers
        )

        rule.events
            .sink { [weak self] evt in
//                guard let self else { return }
//                let ctx = self.snapshotContext()
                guard let self else { return }
                
                print("🧩 TriggerEngine fired rule event: \(evt.reasonSummary)")

                let ctx = self.snapshotContext()

                switch self.mode {
                case .ruleBased:
                    let enriched = InterventionEvent(at: evt.at, reason: evt.reason, context: ctx)
                    // Always publish on main to keep Combine / UI happy
                    DispatchQueue.main.async { [weak self] in
                        self?.eventsSubject.send(enriched)
                    }

                case .llmAugmented:
                    // If no LLM is wired, fall back to rule-based behaviour.
                    guard let llm = self.llm else {
                        let enriched = InterventionEvent(at: evt.at, reason: evt.reason, context: ctx)
                        DispatchQueue.main.async { [weak self] in
                            self?.eventsSubject.send(enriched)
                        }
                        return
                    }
                    Task { [weak self] in
                        guard let self else { return }
                        do {
                            let verdict = try await llm.shouldIntervene(
                                context: ctx,
                                primaryUserID: self.primaryUserID
                            )
                            guard verdict.shouldIntervene else { return }
                            let reason = InterventionReason.llmSuggested(
                                summary: verdict.reason ?? "LLM confirmed intervention."
                            )
                            let enriched = InterventionEvent(at: Date(), reason: reason, context: ctx)
                            DispatchQueue.main.async { [weak self] in
                                self?.eventsSubject.send(enriched)
                            }
                        } catch {
                            // On failure, be conservative and forward the original rule event.
                            let enriched = InterventionEvent(at: evt.at, reason: evt.reason, context: ctx)
                            DispatchQueue.main.async { [weak self] in
                                self?.eventsSubject.send(enriched)
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        cancellables.removeAll()
    }

    // MARK: - Reconfiguration

    /// Enable/disable LLM gating without resetting pause state / context.
    public func updateLLMMode(enabled: Bool, llm evaluator: LLMEvaluator?) {
        if enabled {
            mode = .llmAugmented
            llm = evaluator
        } else {
            mode = .ruleBased
            llm = nil
        }
    }

    /// Change which diarized speaker ID is treated as the "primary" user.
    /// Keeps pause timer and context buffer intact.
    public func updatePrimaryUserID(_ id: String) {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        // Ignore empty / whitespace-only IDs, or re-setting to the same ID.
        guard !trimmed.isEmpty, trimmed != primaryUserID else { return }

        primaryUserID = trimmed
        rule.updatePrimaryUserID(trimmed)
    }

    // MARK: - Public API

    public func receive(_ chunk: TranscriptChunk) {
        bufferQueue.sync {
            buffer.append(chunk)
            let cap = max(contextWindow * 2, contextWindow)
            if buffer.count > cap {
                buffer.removeFirst(buffer.count - cap)
            }
        }
        rule.receive(chunk)
    }

    public func reset() {
        bufferQueue.sync { buffer.removeAll() }
        rule.reset()
    }

    // MARK: - Helpers

    private func snapshotContext() -> [TranscriptChunk] {
        bufferQueue.sync {
            let n = min(contextWindow, buffer.count)
            return Array(buffer.suffix(n))
        }
    }
}
