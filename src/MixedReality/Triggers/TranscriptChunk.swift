import Foundation

/// One piece of transcript coming from ASR (partial or final).
public struct TranscriptChunk: Sendable, Codable, Hashable {
    /// The textual content recognized for this chunk.
    public let text: String

    /// A stable speaker identifier from diarization (e.g., "user", "caregiver", "spk_0").
    public let speakerID: String

    /// Whether this chunk is a finalized segment (as opposed to a partial/interim hypothesis).
    /// For Deepgram, this is set from `is_final` / `speech_final` in TranscriptChunk+Deepgram.
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

    /// Heuristic: whether the chunk is basically just a filler / hesitation.
    /// (We keep this super simple on purpose.)
    public var isFillerOrHesitation: Bool {
        let t = normalizedText
        if t.isEmpty { return false }

        // Common fillers – tweak this list as needed.
        let simpleFillers: Set<String> = [
            "um", "uh", "umm", "hmm", "er", "ah", "like", "you know", "huh"
        ]

        if simpleFillers.contains(t) {
            return true
        }

        // Handle things like "ummmm", "uhhhh...", "mmm..."
        let fillerChars = CharacterSet(charactersIn: "umh.er!?,… ")
        if t.unicodeScalars.allSatisfy({ fillerChars.contains($0) }) {
            return true
        }

        return false
    }

    /// True if this chunk actually carries content (non-empty and not just filler).
    public var isContentful: Bool {
        !isEmptyText && !isFillerOrHesitation
    }
}
