//
//  LLMEvaluator.swift
//  
//
//  Created by Mayowa Adesanya on 2025-11-05.
//
// MixedReality — Criteria 3: LLM toggle layer
//
// Defines a tiny interface to let the trigger engine ask an LLM (or a mock)
// whether an intervention should occur, given recent transcript context.
// MixedReality — Criteria 3: LLM toggle layer

import Foundation

/// Normalized decision from any concrete LLM implementation.
public struct LLMVerdict: Sendable, Equatable {
    public let shouldIntervene: Bool
    public let reason: String?
    public init(shouldIntervene: Bool, reason: String? = nil) {
        self.shouldIntervene = shouldIntervene
        self.reason = reason
    }
}

public protocol LLMEvaluator {
    /// Decide if an intervention is warranted based on recent transcript context.
    /// Implementations should:
    /// - run with a short timeout (~1.5–2.0s) to avoid blocking UX
    /// - be deterministic for identical inputs when possible (for study reproducibility)
    func shouldIntervene(
        context: [TranscriptChunk],
        primaryUserID: String
    ) async throws -> LLMVerdict
}

/// Optional: a lightweight error you may throw from concrete evaluators.
public enum LLMEvaluatorError: Error {
    case timeout
    case cancelled
    case transportFailure(underlying: Error)
    case invalidResponse
}
