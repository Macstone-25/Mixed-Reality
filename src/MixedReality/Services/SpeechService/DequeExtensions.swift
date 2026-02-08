//
//  DequeExtensions.swift
//  MixedReality
//

import Foundation
import Collections

extension Deque where Element == TranscriptChunk {
    /// Inserts a transcript chunk in sorted order based on startAt timestamp.
    /// Ensures chunks remain ordered even when they are finalized out of order.
    /// This method is thread-safe when used within an actor context.
    ///
    /// - Parameter chunk: The transcript chunk to insert
    mutating func insertSorted(_ chunk: TranscriptChunk) {
        // Find the correct insertion point by comparing startAt timestamps
        // We need to iterate from the end to find where this chunk belongs
        var insertIndex = count
        
        // Pop chunks from the end that should come after the new chunk
        var poppedChunks: [TranscriptChunk] = []
        while let last = last, last.startAt > chunk.startAt {
            poppedChunks.append(popLast()!)
            insertIndex -= 1
        }
        
        // Insert the new chunk at the correct position
        append(chunk)
        
        // Re-insert the popped chunks in reverse order
        for poppedChunk in poppedChunks.reversed() {
            append(poppedChunk)
        }
    }
}
