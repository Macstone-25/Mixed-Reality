//
//  PauseEvaluator.swift
//  MixedReality
//

import Collections

/// A simple TriggerEvaluator that triggers an intervention after a configurable duration of silence.
class PauseEvaluator: TriggerEvaluator {
    /// The duration this evaluator should sleep, taking into account the trigger delay settings.
    private let sleepDurationNanoseconds: UInt64
    
    /// The duration this evaluator should report as the actual pause duration.
    private let pauseDurationMs: Int
    
    init(experiment: ExperimentModel) {
        self.sleepDurationNanoseconds = UInt64(max(experiment.pauseDurationMs - experiment.triggerDelayMs, 0)) * 1_000_000
        self.pauseDurationMs = max(experiment.pauseDurationMs, experiment.triggerDelayMs)
    }
    
    func evaluate(chunk: TranscriptChunk, context: [TranscriptChunk]) async -> InterventionReason? {
        do {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: sleepDurationNanoseconds)
            try Task.checkCancellation()
            return InterventionReason.longPause(durationMs: pauseDurationMs)
        } catch {
            return nil
        }
    }
}
