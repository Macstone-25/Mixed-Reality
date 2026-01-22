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
//

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

    /// Lowercased, trimmed form of the text for lightweight analysis.
    public var normalizedText: String {
        text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Number of words (simple whitespace split).
    public var wordCount: Int {
        let parts = normalizedText.split { $0 == " " || $0 == "\n" || $0 == "\t" }
        return parts.count
    }

    /// Heuristic: whether the chunk is basically just a filler / hesitation.
    public var isFillerOrHesitation: Bool {
        let t = normalizedText
        if t.isEmpty { return false }

        let simpleFillers: Set<String> = [
            "um", "uh", "umm", "hmm", "er", "ah", "like", "you know", "huh"
        ]

        if simpleFillers.contains(t) {
            return true
        }

        let fillerChars = CharacterSet(charactersIn: "umh.er!?,… ")
        if t.unicodeScalars.allSatisfy({ fillerChars.contains($0) }) {
            return true
        }

        return false
    }

    /// True if the chunk ends with a filler token (e.g., "um", "uh", "hmm").
    public var endsWithFiller: Bool {
        let t = normalizedText
        if t.isEmpty { return false }

        let fillerEndings: Set<String> = [
            "um", "uh", "umm", "hmm", "er", "ah", "like", "you know", "huh"
        ]

        // Split by whitespace and punctuation, check last token
        let tokens = t
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .filter { !$0.isEmpty }

        guard let last = tokens.last else { return false }
        return fillerEndings.contains(last)
    }

    /// True if this chunk actually carries content (non-empty and not just filler).
    public var isContentful: Bool {
        !isEmptyText && !isFillerOrHesitation
    }
}
