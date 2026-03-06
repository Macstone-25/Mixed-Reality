//
//  FillerEvaluator.swift
//  MixedReality
//
//  Created by William Clubine on 2026-02-01.
//

import Collections
import Foundation

/// Triggers an intervention when filler words repeat excessively.
class FillerEvaluator: TriggerEvaluator {
    private let chunksToCheck: Int
    
    init(chunksToCheck: Int = 3) {
        self.chunksToCheck = chunksToCheck
    }
    
    func evaluate(chunk: TranscriptChunk, context: [TranscriptChunk]) async -> InterventionReason? {
        if chunk.isFinal, let repeatedFillers = chunk.repeatedFillerRun(minCount: chunksToCheck) {
            return InterventionReason.filler(words: repeatedFillers.joined(separator: ", "))
        }
        
        let recentChunks = recentChunksEndingWithCurrent(chunk: chunk, context: context)
        guard recentChunks.count >= chunksToCheck else { return nil }
        guard recentChunks.allSatisfy({ $0.endsWithFiller }) else { return nil }
        
        let fillers = recentChunks.map({ $0.words.last ?? "" })
        return InterventionReason.filler(words: fillers.joined(separator: ", "))
    }
    
    private func recentChunksEndingWithCurrent(chunk: TranscriptChunk, context: [TranscriptChunk]) -> ArraySlice<TranscriptChunk> {
        let chunks = chunk == context.last ? context : context + [chunk]
        return chunks.suffix(chunksToCheck)
    }
}
