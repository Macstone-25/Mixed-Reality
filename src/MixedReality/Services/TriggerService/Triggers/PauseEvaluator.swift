//
//  PauseEvaluator.swift
//  MixedReality
//

import Collections

/// A simple TriggerEvaluator that triggers an intervention after a configurable duration of silence.
class PauseEvaluator: TriggerEvaluator {
    private let sleepDurationMs: UInt64
    
    init(experiment: ExperimentModel) {
        self.sleepDurationMs = UInt64(min(experiment.pauseDurationMs - experiment.triggerDelayMs, 0))
    }
    
    func evaluate(chunk: TranscriptChunk, context: Deque<TranscriptChunk>) async -> InterventionReason? {
        do {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: sleepDurationMs * 1_000_000)
            try Task.checkCancellation()
            return InterventionReason.longPause(durationMs: sleepDurationMs)
        } catch {
            return nil
        }
    }
}
