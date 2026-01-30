// PauseRuleTrigger.swift

import Foundation
import Combine

public final class PauseRuleTrigger {
    private var primaryUserID: String
    private let silenceThreshold: TimeInterval
    private let graceForOthers: TimeInterval

    private var lastPrimarySpeechEnd: Date?
    private var lastSpeakerID: String?

    private var fireTimer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "PauseRuleTrigger.timer")
    private var dueAt: Date?
    private var firedForCurrentSilence = false

    private let eventsSubject = PassthroughSubject<InterventionEvent, Never>()
    public var events: AnyPublisher<InterventionEvent, Never> { eventsSubject.eraseToAnyPublisher() }

    public init(primaryUserID: String,
                silenceThreshold: TimeInterval,
                graceForOthers: TimeInterval) {
        self.primaryUserID = primaryUserID
        self.silenceThreshold = silenceThreshold
        self.graceForOthers = graceForOthers
    }

    deinit { cancelTimer() }

    public func updatePrimaryUserID(_ id: String) {
        primaryUserID = id
        cancelTimer()
        firedForCurrentSilence = false
        lastPrimarySpeechEnd = nil
        lastSpeakerID = nil
        dueAt = nil
    }

    public func receive(_ chunk: TranscriptChunk) {
        lastSpeakerID = chunk.speakerID

        // Any non-final chunk means "speech is ongoing" → push deadline out.
        if !chunk.isFinal {
            firedForCurrentSilence = false
            let newDue = chunk.endAt.addingTimeInterval(silenceThreshold)
            reschedule(to: newDue)
            return
        }

        // For final chunks, only start/reset the baseline on meaningful content.
        let isMeaningful =
            chunk.isContentful &&
            chunk.wordCount >= 3 &&
            !chunk.endsWithFiller

        if isMeaningful {
            lastPrimarySpeechEnd = chunk.endAt
            firedForCurrentSilence = false
            armTimer(after: silenceThreshold, baseline: chunk.endAt)
            return
        }

        // Final filler / short / trailing-filler chunk:
        // treat as continued speech by pushing the deadline out *if a timer exists*.
        if let _ = dueAt, !firedForCurrentSilence {
            let newDue = chunk.endAt.addingTimeInterval(silenceThreshold)
            reschedule(to: newDue)
        }
    }

    public func reset() {
        cancelTimer()
        firedForCurrentSilence = false
        lastPrimarySpeechEnd = nil
        lastSpeakerID = nil
        dueAt = nil
    }

    private func armTimer(after delay: TimeInterval, baseline: Date) {
        cancelTimer()
        let fireDate = baseline.addingTimeInterval(delay)
        dueAt = fireDate

        let t = DispatchSource.makeTimerSource(queue: timerQueue)
        t.schedule(deadline: .now() + max(0, fireDate.timeIntervalSinceNow))
        t.setEventHandler { [weak self] in
            guard let self else { return }
            if self.firedForCurrentSilence { return }
            self.firedForCurrentSilence = true

            let now = Date()
            let elapsed = now.timeIntervalSince(baseline)
            let reason: InterventionReason = .longPause(duration: elapsed)
            let evt = InterventionEvent(at: now, reason: reason, context: [])
            DispatchQueue.main.async { self.eventsSubject.send(evt) }
        }

        fireTimer = t
        t.resume()
    }

    private func reschedule(to newDue: Date) {
        dueAt = newDue
        cancelTimer()

        let remaining = max(0, newDue.timeIntervalSinceNow)
        let t = DispatchSource.makeTimerSource(queue: timerQueue)
        t.schedule(deadline: .now() + remaining)
        t.setEventHandler { [weak self] in
            guard let self else { return }
            if self.firedForCurrentSilence { return }
            self.firedForCurrentSilence = true

            let now = Date()
            let baseline = self.lastPrimarySpeechEnd ?? now
            let elapsed = now.timeIntervalSince(baseline)
            let reason: InterventionReason = .longPause(duration: elapsed)
            let evt = InterventionEvent(at: now, reason: reason, context: [])
            DispatchQueue.main.async { self.eventsSubject.send(evt) }
        }

        fireTimer = t
        t.resume()
    }

    private func cancelTimer() {
        fireTimer?.setEventHandler {}
        fireTimer?.cancel()
        fireTimer = nil
    }
}
