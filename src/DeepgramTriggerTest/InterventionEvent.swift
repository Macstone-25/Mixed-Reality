//
//  InterventionEvent.swift
//
//
//  Created by Mayowa Adesanya on 2025-11-05.
//
// MixedReality — Trigger pipeline models
//
// Describes why/when the system should surface an intervention (e.g., show a prompt)
// and includes lightweight context to help downstream systems (prompt-gen, UI, logging).

import Foundation

/// Why the engine decided to intervene.
public enum InterventionReason: Sendable, Codable, Hashable {
    /// A prolonged silence from the primary user was detected.
    case longPause(duration: TimeInterval)
    /// The LLM (or heuristic LLM layer) recommended intervening and may include a short rationale.
    case llmSuggested(summary: String)

    /// Human-readable summary (safe for logs/telemetry).
    public var summary: String {
        switch self {
        case .longPause(let d): return String(format: "Long pause (%.1fs)", d)
        case .llmSuggested(let s): return s
        }
    }
}

/// An intervention decision emitted by the trigger engine.
public struct InterventionEvent: Identifiable, Sendable, Codable, Hashable {
    /// Stable identity for SwiftUI lists, logging, etc.
    public let id: UUID

    /// Wall-clock time when the decision was made.
    public let at: Date
    /// The reason behind the decision.
    public let reason: InterventionReason
    /// Recent transcript context (last N chunks) to aid prompt generation and UI.
    public let context: [TranscriptChunk]

    public init(
        id: UUID = UUID(),
        at: Date,
        reason: InterventionReason,
        context: [TranscriptChunk]
    ) {
        self.id = id
        self.at = at
        self.reason = reason
        self.context = context
    }

    /// Convenience accessor for logging/telemetry.
    public var reasonSummary: String { reason.summary }
}
