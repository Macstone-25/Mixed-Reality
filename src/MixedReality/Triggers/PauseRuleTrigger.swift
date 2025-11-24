// PauseRuleTrigger.swift

import Foundation
import Combine

public final class PauseRuleTrigger {
    // MARK: - Inputs / config
    private var primaryUserID: String
    private let silenceThreshold: TimeInterval
    private let graceForOthers: TimeInterval

    // MARK: - State
    private var lastPrimarySpeechEnd: Date?
    private var lastSpeakerID: String?

    // One-shot timer machinery
    private var fireTimer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "PauseRuleTrigger.timer")
    private var dueAt: Date?
    private var firedForCurrentSilence = false

    // MARK: - Output
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

    // MARK: - Public API

    public func updatePrimaryUserID(_ id: String) {
        primaryUserID = id
        // Changing who we watch → clear current silence state
        cancelTimer()
        firedForCurrentSilence = false
        lastPrimarySpeechEnd = nil
        lastSpeakerID = nil
        dueAt = nil
    }

    public func receive(_ chunk: TranscriptChunk) {
        guard chunk.isFinal else { return } // only react to final segments

        lastSpeakerID = chunk.speakerID

        // FIXME: if the secondary speaker has multiple chunks timer gets very long!
//        if chunk.speakerID == primaryUserID {
            // Primary spoke → reset baseline and arm a new one-shot timer
            lastPrimarySpeechEnd = chunk.endAt
            firedForCurrentSilence = false
            armTimer(after: silenceThreshold, baseline: chunk.endAt)
//        } else {
//            // Someone else spoke; if we’re currently waiting to fire, extend with grace
//            if let currentDue = dueAt, !firedForCurrentSilence {
//                let newDue = currentDue.addingTimeInterval(graceForOthers)
//                reschedule(to: newDue)
//            }
//        }
    }

    public func reset() {
        cancelTimer()
        firedForCurrentSilence = false
        lastPrimarySpeechEnd = nil
        lastSpeakerID = nil
        dueAt = nil
    }

    // MARK: - Timer helpers

    private func armTimer(after delay: TimeInterval, baseline: Date) {
        cancelTimer()
        let fireDate = baseline.addingTimeInterval(delay)
        dueAt = fireDate

        let t = DispatchSource.makeTimerSource(queue: timerQueue)
        t.schedule(deadline: .now() + max(0, fireDate.timeIntervalSinceNow))
        t.setEventHandler { [weak self] in
            guard let self = self else { return }
            if self.firedForCurrentSilence { return } // only once per silence
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
        // Recreate timer with new remaining time
        cancelTimer()
        let remaining = max(0, newDue.timeIntervalSinceNow)
        let t = DispatchSource.makeTimerSource(queue: timerQueue)
        t.schedule(deadline: .now() + remaining)
        t.setEventHandler { [weak self] in
            guard let self = self else { return }
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
