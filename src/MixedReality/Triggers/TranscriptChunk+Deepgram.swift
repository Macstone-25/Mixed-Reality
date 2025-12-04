//
//  TranscriptChunk+Deepgram.swift
//  MixedReality
//
//  Created by Mayowa Adesanya on 2025-11-13.
//

import Foundation

extension TranscriptChunk {
    /// Build a `TranscriptChunk` from a `DeepgramTranscriptChunk`.
    /// Uses the current wall-clock (`now`) as the end time and infers a start
    /// time from Deepgram word timestamps when available; otherwise uses a small
    /// fallback duration.
    init(from dg: DeepgramTranscriptChunk, now: Date = Date()) {
        let endAt = now
        let duration: TimeInterval =
            (dg.start_time.flatMap { s in dg.end_time.map { e in max(e - s, 0) } }) ?? 0.8
        let startAt = endAt.addingTimeInterval(-duration)

        self.init(
            text: dg.text,
            speakerID: dg.speakerID,
            isFinal: dg.isFinal ?? true,
            startAt: startAt,
            endAt: endAt
        )
    }

}
