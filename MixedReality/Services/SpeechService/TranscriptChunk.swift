//
//  TranscriptChunk.swift
//

import Foundation

/// One piece of transcript coming from ASR (partial or final).
public struct TranscriptChunk: Sendable, Codable, Hashable, CustomStringConvertible {
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
    
    /// A "[Speaker:ID]: text" formatted string for easy logging.
    public var description: String {
        "[\(speakerID)]: \"\(text)\""
    }
    
    /// The text in lowercase without any punctuation.
    public var plainText: String {
        text
            .components(separatedBy: CharacterSet.punctuationCharacters)
            .joined()
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter({ !$0.isEmpty })
            .joined(separator: " ")
            .lowercased()
    }

    /// Number of words (simple whitespace split).
    public var wordCount: Int {
        plainText
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter({ !$0.isEmpty })
            .count
    }

    /// A list of words classified as fillers / hesitation.
    /// https://developers.deepgram.com/docs/filler-words
    private static let fillerWords: Set<String> = [
        "um", "umm", "uh", "uhh", "oh", "hm", "hmm", "er", "ah", "like", "huh"
    ]
    
    /// True if the chunk is only a filler / hesitation word.
    public var isFiller: Bool {
        // TODO: make this more advanced with a small LLM
        TranscriptChunk.fillerWords.contains(plainText)
    }

    /// True if the chunk ends with a filler / hesitation word.
    public var endsWithFiller: Bool {
        // TODO: make this more advanced with a small LLM
        TranscriptChunk.fillerWords.contains(plainText.components(separatedBy: CharacterSet.whitespacesAndNewlines).last ?? "")
    }
}

