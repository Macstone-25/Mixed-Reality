//
//  InterventionEvent.swift
//  MixedReality
//

import Foundation

/// An intervention decision emitted by the trigger engine.
struct InterventionEvent: Identifiable, Sendable, Codable {
    /// Stable identity for SwiftUI lists, logging, etc.
    let id: UInt64

    /// Wall-clock time when the intervention occured.
    let at: Date
    
    /// The reason behind the decision.
    let reason: InterventionReason
    
    /// Recent transcript context (last N chunks) to aid prompt generation and UI.
    let context: [TranscriptChunk]
}
