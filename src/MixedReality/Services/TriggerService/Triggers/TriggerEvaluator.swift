//
//  TriggerEvaluator.swift
//  MixedReality
//

import Collections

enum TriggerEvaluatorError: Error {
    case runtimeError(String)
}

protocol TriggerEvaluator {
    func evaluate(chunk: TranscriptChunk, context: Deque<TranscriptChunk>) async -> InterventionReason?
}
