//
//  TranscriptChunk.swift
//

import Foundation
import Collections

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

extension Deque where Element == TranscriptChunk {
    /// Inserts a transcript chunk in sorted order based on startAt timestamp.
    /// Ensures chunks remain ordered even when they are finalized out of order.
    /// This method is thread-safe when used within an actor context.
    ///
    /// - Parameter chunk: The transcript chunk to insert
    @inlinable
    nonisolated public mutating func insertSorted(_ chunk: TranscriptChunk) {
        // Pop chunks from the end that should come after the new chunk
        var poppedChunks: [TranscriptChunk] = []
        while let last = last, last.startAt > chunk.startAt {
            poppedChunks.append(popLast()!)
        }
        
        // Insert the new chunk at the correct position
        append(chunk)
        
        // Re-insert the popped chunks in reverse order
        for poppedChunk in poppedChunks.reversed() {
            append(poppedChunk)
        }
    }
}
