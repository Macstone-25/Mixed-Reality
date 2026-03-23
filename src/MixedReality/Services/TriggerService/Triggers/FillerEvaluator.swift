//
//  FillerEvaluator.swift
//  MixedReality
//
//  Created by William Clubine on 2026-02-01.
//

import Foundation

/// Triggers an intervention when filler words repeat excessively.
class FillerEvaluator: TriggerEvaluator {
    private let chunksToCheck: Int
    private let fillerBurstGapThreshold: TimeInterval
    private let replayTimingTolerance: TimeInterval
    
    init(
        chunksToCheck: Int = 3,
        fillerBurstGapThreshold: TimeInterval = 3,
        replayTimingTolerance: TimeInterval = 0.25
    ) {
        self.chunksToCheck = chunksToCheck
        self.fillerBurstGapThreshold = fillerBurstGapThreshold
        self.replayTimingTolerance = replayTimingTolerance
    }
    
    func evaluate(chunk: TranscriptChunk, context: [TranscriptChunk]) async -> InterventionReason? {
        if let repeatedFillers = chunk.repeatedFillerFamilyRun(minCount: chunksToCheck) {
            return InterventionReason.filler(words: repeatedFillers.joined(separator: ", "))
        }
        
        if let repeatedFillers = repeatedFillerBurstAcrossChunks(chunk: chunk, context: context) {
            return InterventionReason.filler(words: repeatedFillers.joined(separator: ", "))
        }
        
        let recentFinalChunks = recentFinalChunksEndingWithCurrent(chunk: chunk, context: context)
        guard recentFinalChunks.count >= chunksToCheck else { return nil }
        guard recentFinalChunks.allSatisfy(\.endsWithFiller) else { return nil }
        
        let fillers = recentFinalChunks.map({ $0.words.last ?? "" })
        return InterventionReason.filler(words: fillers.joined(separator: ", "))
    }
    
    private func repeatedFillerBurstAcrossChunks(chunk: TranscriptChunk, context: [TranscriptChunk]) -> [String]? {
        guard chunk.isOnlyRepeatedFillerWords else { return nil }
        
        let chunks = distinctChunksEndingWithCurrent(chunk: chunk, context: context)
        var burstFamilies = [String]()
        var earliestStartAt = chunk.startAt
        
        for candidate in chunks.reversed() {
            guard candidate.speakerID == chunk.speakerID else { break }
            guard candidate.isOnlyRepeatedFillerWords else { break }
            
            if earliestStartAt - candidate.endAt > fillerBurstGapThreshold {
                break
            }
            
            burstFamilies.insert(contentsOf: candidate.normalizedRepeatedFillerWords, at: 0)
            earliestStartAt = min(earliestStartAt, candidate.startAt)
            
            if let run = TranscriptChunk.repeatedNormalizedFillerFamilyRun(
                in: burstFamilies,
                minCount: chunksToCheck
            ) {
                return run
            }
        }
        
        return nil
    }
    
    private func distinctChunksEndingWithCurrent(chunk: TranscriptChunk, context: [TranscriptChunk]) -> [TranscriptChunk] {
        let chunks = orderedChunksEndingWithCurrent(chunk: chunk, context: context)
        var distinctChunks = [TranscriptChunk]()
        
        for candidate in chunks {
            if isReplayDuplicate(candidate, comparedTo: distinctChunks.last) {
                continue
            }
            distinctChunks.append(candidate)
        }
        
        return distinctChunks
    }
    
    private func orderedChunksEndingWithCurrent(chunk: TranscriptChunk, context: [TranscriptChunk]) -> [TranscriptChunk] {
        if let chunkIndex = context.lastIndex(of: chunk) {
            return Array(context[...chunkIndex])
        }
        
        return context + [chunk]
    }
    
    private func recentFinalChunksEndingWithCurrent(
        chunk: TranscriptChunk,
        context: [TranscriptChunk]
    ) -> ArraySlice<TranscriptChunk> {
        var finalChunks = context.filter(\.isFinal)
        
        if chunk.isFinal && chunk != finalChunks.last {
            finalChunks.append(chunk)
        }
        
        return finalChunks.suffix(chunksToCheck)
    }
    
    private func isReplayDuplicate(_ chunk: TranscriptChunk, comparedTo lastChunk: TranscriptChunk?) -> Bool {
        guard let lastChunk else { return false }
        guard chunk.speakerID == lastChunk.speakerID else { return false }
        guard chunk.text == lastChunk.text else { return false }
        guard abs(chunk.startAt - lastChunk.startAt) <= replayTimingTolerance else { return false }
        guard abs(chunk.endAt - lastChunk.endAt) <= replayTimingTolerance else { return false }
        return true
    }
}
