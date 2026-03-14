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
    private let fillerBurstGapThreshold: TimeInterval
    private let refinementOverlapTolerance: TimeInterval
    
    private struct FillerBurstSegment {
        let families: [String]
        let startAt: Double
        let endAt: Double
    }
    
    private struct SentenceWindowSegment {
        let families: [String]
        let startAt: Double
        let endAt: Double
        let hasInternalBoundary: Bool
    }
    
    private struct FillerEventFingerprint: Hashable {
        let speakerID: String
        let roundedStartBucket: Int
        let roundedEndBucket: Int
        let families: [String]
    }
    
    init(
        chunksToCheck: Int = 3,
        fillerBurstGapThreshold: TimeInterval = 3,
        refinementOverlapTolerance: TimeInterval = 0.25
    ) {
        self.chunksToCheck = chunksToCheck
        self.fillerBurstGapThreshold = fillerBurstGapThreshold
        self.refinementOverlapTolerance = refinementOverlapTolerance
    }
    
    func evaluate(chunk: TranscriptChunk, context: [TranscriptChunk]) async -> InterventionReason? {
        if chunk.isFinal, let repeatedFillers = chunk.repeatedFillerFamilyRun(minCount: chunksToCheck) {
            return InterventionReason.filler(words: repeatedFillers.joined(separator: ", "))
        }
        
        if let repeatedFillers = repeatedFillerBurst(chunk: chunk, context: context) {
            return InterventionReason.filler(words: repeatedFillers.joined(separator: ", "))
        }
        
        if let repeatedFillers = repeatedFillersWithinSentence(chunk: chunk, context: context) {
            return InterventionReason.filler(words: repeatedFillers.joined(separator: ", "))
        }
        
        let recentFinalChunks = recentFinalChunksEndingWithCurrent(chunk: chunk, context: context)
        guard recentFinalChunks.count >= chunksToCheck else { return nil }
        guard recentFinalChunks.allSatisfy({ $0.endsWithFiller }) else { return nil }
        
        let fillers = recentFinalChunks.map({ $0.words.last ?? "" })
        return InterventionReason.filler(words: fillers.joined(separator: ", "))
    }
    
    private func repeatedFillerBurst(chunk: TranscriptChunk, context: [TranscriptChunk]) -> [String]? {
        let burstSegments = recentSameSpeakerFillerBurst(chunk: chunk, context: context)
        let uniqueBurstSegments = uniqueFillerBurstSegments(
            burstSegments,
            speakerID: chunk.speakerID
        )
        let normalizedFamilies = uniqueBurstSegments.flatMap(\.families)
        guard normalizedFamilies.count >= chunksToCheck else { return nil }
        return TranscriptChunk.repeatedNormalizedFillerFamilyRun(
            in: normalizedFamilies,
            minCount: chunksToCheck
        )
    }
    
    private func repeatedFillersWithinSentence(chunk: TranscriptChunk, context: [TranscriptChunk]) -> [String]? {
        let sentenceSegments = recentSameSpeakerSentenceWindow(chunk: chunk, context: context)
        let uniqueSentenceSegments = uniqueSentenceWindowSegments(
            sentenceSegments,
            speakerID: chunk.speakerID
        )
        var familyCounts = OrderedDictionary<String, Int>()
        
        for family in uniqueSentenceSegments.flatMap(\.families) {
            familyCounts[family, default: 0] += 1
            
            if let count = familyCounts[family], count >= chunksToCheck {
                return Array(repeating: family, count: count)
            }
        }
        
        return nil
    }
    
    private func recentSameSpeakerFillerBurst(chunk: TranscriptChunk, context: [TranscriptChunk]) -> [FillerBurstSegment] {
        guard chunk.isOnlyRepeatedFillerWords else { return [] }
        
        let chunks = orderedChunksEndingWithCurrent(chunk: chunk, context: context)
        var burstSegments = [FillerBurstSegment]()
        
        for candidate in chunks.reversed() {
            guard candidate.speakerID == chunk.speakerID else { break }
            guard candidate.isOnlyRepeatedFillerWords else { break }
            
            let families = candidate.normalizedRepeatedFillerWords
            
            if let earliestSegment = burstSegments.first {
                if earliestSegment.startAt - candidate.endAt > fillerBurstGapThreshold {
                    break
                }
                
                // Overlapping chunks are usually interim/final refinements of the
                // same audio, so merge matching chunks and ignore conflicting ones.
                if candidate.endAt > earliestSegment.startAt {
                    if candidate.normalizedRepeatedFillerWords == earliestSegment.families {
                        if isNearRefinement(
                            candidateStartAt: candidate.startAt,
                            candidateEndAt: candidate.endAt,
                            existingStartAt: earliestSegment.startAt,
                            existingEndAt: earliestSegment.endAt
                        ) {
                            burstSegments[0] = FillerBurstSegment(
                                families: earliestSegment.families,
                                startAt: min(candidate.startAt, earliestSegment.startAt),
                                endAt: max(candidate.endAt, earliestSegment.endAt)
                            )
                            continue
                        }
                    } else {
                        continue
                    }
                }
            }
            
            burstSegments.insert(
                FillerBurstSegment(
                    families: families,
                    startAt: candidate.startAt,
                    endAt: candidate.endAt
                ),
                at: 0
            )
        }
        
        return burstSegments
    }
    
    private func recentSameSpeakerSentenceWindow(chunk: TranscriptChunk, context: [TranscriptChunk]) -> [SentenceWindowSegment] {
        let chunks = orderedChunksEndingWithCurrent(chunk: chunk, context: context)
        var sentenceSegments = [SentenceWindowSegment]()
        
        for candidate in chunks.reversed() {
            guard candidate.speakerID == chunk.speakerID else { break }
            
            if let earliestSegment = sentenceSegments.first {
                if earliestSegment.startAt - candidate.endAt > fillerBurstGapThreshold {
                    break
                }
                
                // Prefer the newest chunk when ASR sends overlapping refinements.
                if candidate.endAt > earliestSegment.startAt {
                    if isNearRefinement(
                        candidateStartAt: candidate.startAt,
                        candidateEndAt: candidate.endAt,
                        existingStartAt: earliestSegment.startAt,
                        existingEndAt: earliestSegment.endAt
                    ) {
                        continue
                    }
                }
                
                if candidate.isFinal && candidate.endsSentence {
                    break
                }
            }
            
            let segment = SentenceWindowSegment(
                families: candidate.lastSentenceNormalizedFillerWords,
                startAt: candidate.startAt,
                endAt: candidate.endAt,
                hasInternalBoundary: candidate.hasSentenceBoundaryBeforeLastSentence
            )
            sentenceSegments.insert(segment, at: 0)
            
            if candidate.hasSentenceBoundaryBeforeLastSentence {
                break
            }
        }
        
        return sentenceSegments
    }
    
    private func orderedChunksEndingWithCurrent(chunk: TranscriptChunk, context: [TranscriptChunk]) -> [TranscriptChunk] {
        if let chunkIndex = context.lastIndex(of: chunk) {
            return Array(context[...chunkIndex])
        }
        
        return context + [chunk]
    }
    
    private func recentFinalChunksEndingWithCurrent(chunk: TranscriptChunk, context: [TranscriptChunk]) -> ArraySlice<TranscriptChunk> {
        var finalChunks = context.filter({ $0.isFinal })
        
        if chunk.isFinal && chunk != finalChunks.last {
            finalChunks.append(chunk)
        }
        
        return finalChunks.suffix(chunksToCheck)
    }
    
    private func isNearRefinement(
        candidateStartAt: Double,
        candidateEndAt: Double,
        existingStartAt: Double,
        existingEndAt: Double
    ) -> Bool {
        abs(candidateStartAt - existingStartAt) <= refinementOverlapTolerance &&
        abs(candidateEndAt - existingEndAt) <= refinementOverlapTolerance
    }
    
    private func uniqueFillerBurstSegments(
        _ segments: [FillerBurstSegment],
        speakerID: String
    ) -> [FillerBurstSegment] {
        var seen = Set<FillerEventFingerprint>()
        var uniqueSegments = [FillerBurstSegment]()
        
        for segment in segments {
            let fingerprint = FillerEventFingerprint(
                speakerID: speakerID,
                roundedStartBucket: roundedTimeBucket(segment.startAt),
                roundedEndBucket: roundedTimeBucket(segment.endAt),
                families: segment.families
            )
            
            if seen.insert(fingerprint).inserted {
                uniqueSegments.append(segment)
            }
        }
        
        return uniqueSegments
    }
    
    private func uniqueSentenceWindowSegments(
        _ segments: [SentenceWindowSegment],
        speakerID: String
    ) -> [SentenceWindowSegment] {
        var seen = Set<FillerEventFingerprint>()
        var uniqueSegments = [SentenceWindowSegment]()
        
        for segment in segments {
            let fingerprint = FillerEventFingerprint(
                speakerID: speakerID,
                roundedStartBucket: roundedTimeBucket(segment.startAt),
                roundedEndBucket: roundedTimeBucket(segment.endAt),
                families: segment.families
            )
            
            if seen.insert(fingerprint).inserted {
                uniqueSegments.append(segment)
            }
        }
        
        return uniqueSegments
    }
    
    private func roundedTimeBucket(_ timestamp: Double) -> Int {
        Int((timestamp * 10).rounded())
    }
}
