//
//  TranscriptChunk.swift
//
//
//  Created by Mayowa Adesanya on 2025-11-05.
//
// MixedReality — Trigger pipeline models
//
// Represents a single chunk/utterance coming from the ASR pipeline.
// Keep this type lightweight; it’s passed across services and into the trigger engine.

import Foundation

/// One piece of transcript coming from ASR (partial or final).
public struct TranscriptChunk: Sendable, Codable, Hashable {
    /// The textual content recognized for this chunk.
    public let text: String
    /// A stable speaker identifier from diarization (e.g., "user", "caregiver", "spk_0").
    public let speakerID: String
    /// Whether this chunk is a finalized segment (as opposed to a partial/interim hypothesis).
    public let isFinal: Bool
    /// When this chunk’s audio began (wall-clock).
    public let startAt: Date
    /// When this chunk’s audio ended (wall-clock).
    public let endAt: Date

    public init(
        text: String,
        speakerID: String,
        isFinal: Bool,
        startAt: Date,
        endAt: Date
    ) {
        self.text = text
        self.speakerID = speakerID
        self.isFinal = isFinal
        self.startAt = startAt
        self.endAt = endAt
    }

    /// Duration of the audio covered by this chunk.
    public var duration: TimeInterval { endAt.timeIntervalSince(startAt) }

    /// True if the (trimmed) text is empty.
    public var isEmptyText: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
