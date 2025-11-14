// TranscriptChunk+Deepgram.swift

import Foundation

extension TranscriptChunk {
    /// Build a `TranscriptChunk` from a `DeepgramTranscriptChunk`.
    /// Uses the current wall-clock (`now`) as the end time and infers a start
    /// time from Deepgram word timestamps when available; otherwise uses a small
    /// fallback duration.
    init(from dg: DeepgramTranscriptChunk, now: Date = Date()) {
        // Deepgram can send isFinal as optional → coalesce to false
        let finalFlag = dg.isFinal ?? false

        let endAt = now

        let duration: TimeInterval
        if let s = dg.start_time, let e = dg.end_time, e > s {
            duration = e - s
        } else {
            duration = 0.8
        }

        let startAt = endAt.addingTimeInterval(-duration)

        self.init(
            text: dg.text,
            speakerID: dg.speakerID,
            isFinal: finalFlag,
            startAt: startAt,
            endAt: endAt
        )
    }
}
