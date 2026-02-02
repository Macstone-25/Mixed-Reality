//
//  InterventionReason.swift
//  MixedReality
//

import Foundation

/// Why the engine decided to intervene.
enum InterventionReason: CustomStringConvertible, Sendable, Codable {
    /// A prolonged silence was detected.
    case longPause(durationMs: UInt64)
    
    /// The LLM recommended intervening and may include a short rationale.
    case llmSuggested(rationale: String)
    
    /// A series of filler words was detected.
    case filler(words: String)
    
    var description: String {
        switch self {
        case .longPause(let duration): return String(format: "Long pause (%.1fs)", duration)
        case .llmSuggested(let rationale): return rationale
        case .filler(let words): return "Filler words (\(words))"
        }
    }
}
