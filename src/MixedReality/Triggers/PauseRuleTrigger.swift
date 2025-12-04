import Foundation
import Combine

/// Rule that fires when the *primary* user has gone a long time
/// without saying anything *contentful* (non-filler).
///
/// Key behaviour:
/// - We measure silence from the **last non-filler chunk** by the primary user.
/// - Filler / hesitation chunks (e.g. "um", "uh") from the primary user
///   do **not** reset the baseline timer.
/// - Speech from *other* speakers can extend the deadline by `graceForOthers`.
public final class PauseRuleTrigger {
    // MARK: - Inputs / config

    private var primaryUserID: String
    private let silenceThreshold: TimeInterval
    private let graceForOthers: TimeInterval

    // MARK: - State

    /// End time of the last *contentful* (non-filler) chunk from the primary user.
    private var lastPrimaryContentfulEnd: Date?

    /// End time of the last *any* chunk from the primary user (contentful or filler).
    /// Not currently used in the timer math, but kept for possible future heuristics.
    private var lastPrimaryAnySpeechEnd: Date?

    private var lastSpeakerID: String?

    // One-shot timer machinery
    private var fireTimer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "PauseRuleTrigger.timer")

    /// When the current timer is scheduled to fire.
    private var dueAt: Date?

    /// Ensures we only fire once per silence episode.
    private var firedForCurrentSilence = false

    // MARK: - Output

    private let eventsSubject = PassthroughSubject<InterventionEvent, Never>()
    public var events: AnyPublisher<InterventionEvent, Never> {
        eventsSubject.eraseToAnyPublisher()
    }

    // MARK: - Init

    public init(
        primaryUserID: String,
        silenceThreshold: TimeInterval,
        graceForOthers: TimeInterval
    ) {
        self.primaryUserID = primaryUserID
        self.silenceThreshold = silenceThreshold
        self.graceForOthers = graceForOthers
    }

    deinit {
        cancelTimer()
    }

    // MARK: - Public API

    public func updatePrimaryUserID(_ id: String) {
        primaryUserID = id

        // Changing who we watch → clear current silence state.
        cancelTimer()
        firedForCurrentSilence = false
        lastPrimaryContentfulEnd = nil
        lastPrimaryAnySpeechEnd = nil
        lastSpeakerID = nil
        dueAt = nil
    }

    public func receive(_ chunk: TranscriptChunk) {
        lastSpeakerID = chunk.speakerID

        // We only care about actual text; an entirely empty chunk is irrelevant.
        if chunk.isEmptyText {
            return
        }

        if chunk.speakerID == primaryUserID {
            handlePrimaryChunk(chunk)
        } else {
            handleOtherSpeakerChunk(chunk)
        }
    }

    public func reset() {
        cancelTimer()
        firedForCurrentSilence = false
        lastPrimaryContentfulEnd = nil
        lastPrimaryAnySpeechEnd = nil
        lastSpeakerID = nil
        dueAt = nil
    }

    // MARK: - Internal handlers

    private func handlePrimaryChunk(_ chunk: TranscriptChunk) {
        let end = chunk.endAt

        // Track that the primary user said *something* at this time.
        lastPrimaryAnySpeechEnd = end

        if chunk.isContentful {
            // This is a non-filler utterance → reset our "last meaningful speech" baseline.
            lastPrimaryContentfulEnd = end
            firedForCurrentSilence = false

            // Arm a new one-shot timer for `silenceThreshold` after this contentful end time.
            armTimer(after: silenceThreshold, baseline: end)
        } else {
            // Filler / hesitation:
            //
            // We *do not* reset the baseline for silence here.
            // That means "um... um..." for 4s after the last contentful word
            // is treated the same as pure silence for 4s.
            //
            // If there is no `lastPrimaryContentfulEnd` yet (conversation started
            // with only filler), we simply don't start a timer – there's no
            // meaningful topic to "resume" from.
        }
    }

    private func handleOtherSpeakerChunk(_ chunk: TranscriptChunk) {
        // Someone else spoke; if we’re currently waiting to fire, extend with grace.
        if let currentDue = dueAt, !firedForCurrentSilence {
            let newDue = currentDue.addingTimeInterval(graceForOthers)
            reschedule(to: newDue)
        }
    }

    // MARK: - Timer helpers

    private func armTimer(after delay: TimeInterval, baseline: Date) {
        cancelTimer()

        // We only arm timers once we have a meaningful contentful baseline.
        guard lastPrimaryContentfulEnd != nil else {
            return
        }

        let fireDate = baseline.addingTimeInterval(delay)
        dueAt = fireDate

        let t = DispatchSource.makeTimerSource(queue: timerQueue)
        t.schedule(deadline: .now() + max(0, fireDate.timeIntervalSinceNow))

        t.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.handleTimerFire()
        }

        fireTimer = t
        t.resume()
    }

    private func reschedule(to newDue: Date) {
        dueAt = newDue

        // If there’s never been contentful speech from the primary,
        // there’s nothing meaningful to measure silence from.
        guard lastPrimaryContentfulEnd != nil else {
            cancelTimer()
            return
        }

        cancelTimer()

        let remaining = max(0, newDue.timeIntervalSinceNow)
        let t = DispatchSource.makeTimerSource(queue: timerQueue)
        t.schedule(deadline: .now() + remaining)

        t.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.handleTimerFire()
        }

        fireTimer = t
        t.resume()
    }

    private func handleTimerFire() {
        if firedForCurrentSilence {
            return  // Only one intervention per silence span.
        }

        // We *must* have a contentful baseline; otherwise this rule shouldn’t fire.
        guard let baselineTime = lastPrimaryContentfulEnd else {
            return
        }

        let now = Date()
        let elapsed = now.timeIntervalSince(baselineTime)

        // Safety guard: ignore spurious early fires (timer jitter, re-arm races, etc.).
        if elapsed < silenceThreshold * 0.75 {
            return
        }

        firedForCurrentSilence = true

        let reason: InterventionReason = .longPause(duration: elapsed)
        let evt = InterventionEvent(at: now, reason: reason, context: [])

        DispatchQueue.main.async { [eventsSubject] in
            eventsSubject.send(evt)
        }
    }

    private func cancelTimer() {
        fireTimer?.setEventHandler {}
        fireTimer?.cancel()
        fireTimer = nil
    }
}
