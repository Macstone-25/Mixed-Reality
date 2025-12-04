//
//  TranscriptFormatter.swift
//  MixedReality
//
//  Created by Mayowa Adesanya on 2025-12-02.
//
import Foundation

/// Utility to take a list of TranscriptChunks and produce cleaner,
/// less-choppy “turns” for logging or prompt generation.
struct TranscriptFormatter {

    static func mergedTurns(
        from chunks: [TranscriptChunk],
        maxGap: TimeInterval = 1.5,
        dropFillerOnly: Bool = true
    ) -> [TranscriptChunk] {
        let sorted = chunks.sorted { $0.startAt < $1.startAt }

        var result: [TranscriptChunk] = []
        var current: TranscriptChunk?

        for c in sorted {
            if dropFillerOnly && !c.isContentful {
                continue
            }

            guard var prev = current else {
                current = c
                continue
            }

            let sameSpeaker = (prev.speakerID == c.speakerID)
            let gap = c.startAt.timeIntervalSince(prev.endAt)

            if sameSpeaker && gap <= maxGap {
                let merged = TranscriptChunk(
                    text: prev.text + " " + c.text,
                    speakerID: prev.speakerID,
                    isFinal: prev.isFinal || c.isFinal,
                    startAt: prev.startAt,
                    endAt: c.endAt
                )
                current = merged
            } else {
                result.append(prev)
                current = c
            }
        }

        if let current {
            result.append(current)
        }

        return result
    }

    static func asLines(_ chunks: [TranscriptChunk]) -> String {
        mergedTurns(from: chunks).map { c in
            "\(c.speakerID): \(c.text)"
        }
        .joined(separator: "\n")
    }
}
