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
    
    /// Lowercased words with punctuation removed.
    var words: [String] {
        TranscriptChunk.normalizedWords(in: text)
    }

    /// Number of words (simple whitespace split).
    public var wordCount: Int {
        words.count
    }

    /// A list of words classified as fillers / hesitation.
    /// https://developers.deepgram.com/docs/filler-words
    nonisolated private static let fillerWords: Set<String> = [
        "um", "umm", "uh", "uhh", "oh", "hm", "hmm", "er", "ah", "like", "huh"
    ]
    
    /// Words that should only count when repeated several times in a row.
    nonisolated private static let repeatedOnlyFillerWords: Set<String> = [
        "and"
    ]
    
    nonisolated private static let repeatedFillerWords = fillerWords.union(repeatedOnlyFillerWords)
    
    nonisolated private static func normalizedWords(in text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet.punctuationCharacters)
            .joined()
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter({ !$0.isEmpty })
            .map({ $0.lowercased() })
    }
    
    nonisolated static func repeatedFillerFamily(for word: String) -> String? {
        guard repeatedFillerWords.contains(word) else { return nil }
        
        switch word {
        case "um", "umm":
            return "um"
        case "uh", "uhh":
            return "uh"
        case "hm", "hmm":
            return "hm"
        default:
            return word
        }
    }
    
    nonisolated static func repeatedNormalizedFillerFamilyRun(in families: [String], minCount: Int = 3) -> [String]? {
        var currentFamily: String?
        var currentCount = 0
        
        for family in families {
            if family == currentFamily {
                currentCount += 1
            } else {
                currentFamily = family
                currentCount = 1
            }
            
            if currentCount >= minCount, let currentFamily {
                return Array(repeating: currentFamily, count: currentCount)
            }
        }
        
        return nil
    }
    
    nonisolated static func repeatedFillerFamilyRun(in words: [String], minCount: Int = 3) -> [String]? {
        var normalizedFamilies = [String]()
        
        for word in words {
            guard let family = repeatedFillerFamily(for: word) else {
                if let run = repeatedNormalizedFillerFamilyRun(in: normalizedFamilies, minCount: minCount) {
                    return run
                }
                normalizedFamilies.removeAll(keepingCapacity: true)
                continue
            }
            
            normalizedFamilies.append(family)
        }
        
        return repeatedNormalizedFillerFamilyRun(in: normalizedFamilies, minCount: minCount)
    }
    
    /// True if the chunk is only a filler / hesitation word.
    public var isFiller: Bool {
        TranscriptChunk.fillerWords.contains(plainText)
    }

    /// True if the chunk ends with a filler / hesitation word.
    public var endsWithFiller: Bool {
        TranscriptChunk.fillerWords.contains(words.last ?? "")
    }
    
    var normalizedRepeatedFillerWords: [String] {
        words.compactMap(TranscriptChunk.repeatedFillerFamily(for:))
    }
    
    var isOnlyRepeatedFillerWords: Bool {
        !words.isEmpty && words.count == normalizedRepeatedFillerWords.count
    }
    
    /// Returns a consecutive run of repeated filler families, if present.
    func repeatedFillerFamilyRun(minCount: Int = 3) -> [String]? {
        TranscriptChunk.repeatedFillerFamilyRun(in: words, minCount: minCount)
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
