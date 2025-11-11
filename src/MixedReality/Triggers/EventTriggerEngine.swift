// EventTriggerEngine.swift
//
// MixedReality — Criteria 1: orchestrator + public API
//
// Consumes transcript chunks, runs the pause rule, and (optionally) confirms
// with an LLM layer before emitting intervention events to subscribers.

import Foundation
import Combine

public final class EventTriggerEngine: InterventionTriggering {
    // MARK: - Modes
    public enum Mode { case ruleBased, llmAugmented }

    // MARK: - Dependencies
    private let primaryUserID: String
    private let mode: Mode
    private let llm: LLMEvaluator?
    private let rule: PauseRuleTrigger

    // MARK: - Context buffer
    /// How many recent chunks to keep for context/LLM.
    private let contextWindow: Int
    private var buffer: [TranscriptChunk] = []
    private let bufferQueue = DispatchQueue(label: "EventTriggerEngine.buffer")

    // MARK: - Outputs
    private let eventsSubject = PassthroughSubject<InterventionEvent, Never>()
    public var events: AnyPublisher<InterventionEvent, Never> { eventsSubject.eraseToAnyPublisher() }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    /// - Parameters:
    ///   - primaryUserID: diarization ID treated as the main participant to monitor
    ///   - silenceThreshold: seconds of silence from the primary user to trigger
    ///   - graceForOthers: extra seconds added when others spoke after the primary user
    ///   - mode: `.ruleBased` (fast) or `.llmAugmented` (rule + LLM confirmation)
    ///   - llm: LLM evaluator used only when `mode == .llmAugmented`
    ///   - contextWindow: how many recent chunks to attach to events and send to LLM
    public init(
        primaryUserID: String,
        silenceThreshold: TimeInterval = 4.0,
        graceForOthers: TimeInterval = 2.0,
        mode: Mode = .ruleBased,
        llm: LLMEvaluator? = nil,
        contextWindow: Int = 8
    ) {
        self.primaryUserID = primaryUserID
        self.mode = mode
        self.llm = llm
        self.contextWindow = max(1, contextWindow)
        self.rule = PauseRuleTrigger(
            primaryUserID: primaryUserID,
            silenceThreshold: silenceThreshold,
            graceForOthers: graceForOthers
        )

        // Subscribe to rule events and optionally pass through an LLM gate.
        rule.events
            .sink { [weak self] evt in
                guard let self else { return }
                let ctx = self.snapshotContext()

                switch self.mode {
                case .ruleBased:
                    // Attach context and forward immediately.
                    let enriched = InterventionEvent(at: evt.at, reason: evt.reason, context: ctx)
                    self.eventsSubject.send(enriched)

                case .llmAugmented:
                    // Confirm with LLM (non-blocking). If LLM is absent, fall back to send.
                    guard let llm = self.llm else {
                        let enriched = InterventionEvent(at: evt.at, reason: evt.reason, context: ctx)
                        self.eventsSubject.send(enriched)
                        return
                    }
                    Task {
                        do {
                            let verdict: LLMVerdict = try await llm.shouldIntervene(
                                context: ctx,
                                primaryUserID: self.primaryUserID
                            )
                            guard verdict.shouldIntervene else { return }
                            let reason = InterventionReason.llmSuggested(
                                summary: verdict.reason ?? "LLM confirmed intervention."
                            )
                            let enriched = InterventionEvent(at: Date(), reason: reason, context: ctx)
                            self.eventsSubject.send(enriched)
                        } catch {
                            // On failure, be conservative: forward the original event with context.
                            let enriched = InterventionEvent(at: evt.at, reason: evt.reason, context: ctx)
                            self.eventsSubject.send(enriched)
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    deinit { cancellables.removeAll() }

    // MARK: - Public API
    public func receive(_ chunk: TranscriptChunk) {
        // Track context window
        bufferQueue.sync {
            buffer.append(chunk)
            // Keep up to 2x the window to give LLM a bit more history without growing unbounded.
            let cap = max(contextWindow * 2, contextWindow)
            if buffer.count > cap { buffer.removeFirst(buffer.count - cap) }
        }
        // Update rule
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
