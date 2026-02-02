//
//  TranscriptChunk.swift
//

import Foundation

/// One piece of transcript coming from ASR (partial or final).
public struct TranscriptChunk: Sendable, Codable, Hashable {
    /// The speech recognized for this chunk.
    public let text: String
    /// The diarized speaker for this chunk (volatile).
    public let speakerID: String
    /// Whether this chunk is a finalized segment (as opposed to a partial speech fragment).
    public let isFinal: Bool
    /// When this chunk’s audio began.
    public let startAt: Double
    /// When this chunk’s audio ended.
    public let endAt: Double

    /// Duration of the audio covered by this chunk.
    public var duration: TimeInterval { endAt - startAt }

    /// Number of words (simple whitespace split).
    public var wordCount: Int {
        return text
            .components(separatedBy: CharacterSet.whitespaces)
            .count
    }

    /// A list of words classified as fillers / hesitation.
    private static let fillerWords: Set<String> = [
        "um", "uh", "umm", "hmm", "er", "ah", "like", "you know", "huh"
    ]
    
    /// True if the chunk is only a filler / hesitation word.
    public var isFiller: Bool {
        // TODO: make this more advanced with a small LLM
        if TranscriptChunk.fillerWords.contains(text) {
            return true
        }

        return false
    }

    /// True if the chunk ends with a filler / hesitation word.
    public var endsWithFiller: Bool {
        // TODO: make this more advanced with a small LLM
        // Split by whitespace and punctuation, check last token
        let tokens = text
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .filter { !$0.isEmpty }

        guard let lastToken = tokens.last else { return false }
        return TranscriptChunk.fillerWords.contains(lastToken)
    }
}
