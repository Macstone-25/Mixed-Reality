//
//  FillerEvaluator.swift
//  MixedReality
//
//  Created by William Clubine on 2026-02-01.
//

import Collections
import Foundation

/// Triggers an intervention if the past 3 transcript chunks have ended with filler words.
class FillerEvaluator: TriggerEvaluator {
    private let chunksToCheck: Int
    
    init(chunksToCheck: Int = 3) {
        self.chunksToCheck = chunksToCheck
    }
    
    func evaluate(chunk: TranscriptChunk, context: Deque<TranscriptChunk>) async -> InterventionReason? {
        // If we don't have enough chunks to check yet, we can immediately ignore this chunk
        guard context.count > chunksToCheck else { return nil }
        
        // If the current chunk was already added to the context, we need to look back one more element
        let chunksToCheck = chunk == context.last ? chunksToCheck + 1 : chunksToCheck
        
        // Check that the current chunk ends with filler
        guard chunk.endsWithFiller else { return nil }
        
        // Check that the previous chunksToCheck chunks end with filler
        guard context.suffix(chunksToCheck).allSatisfy({ $0.endsWithFiller }) else { return nil }
        
        var fillers = context.suffix(chunksToCheck).map({
            $0.plainText.components(separatedBy: CharacterSet.whitespacesAndNewlines).last!
        })
        
        if chunk != context.last {
            fillers.append(chunk.plainText.components(separatedBy: CharacterSet.whitespacesAndNewlines).last!)
        }
        
        return InterventionReason.filler(words: fillers.joined(separator: ", "))
    }
}
