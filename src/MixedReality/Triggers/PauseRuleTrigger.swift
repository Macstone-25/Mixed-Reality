//
//  PauseRuleTrigger.swift
//  
//
//  Created by Mayowa Adesanya on 2025-11-05.
//
// MixedReality — Criteria 2: simple pause-based detection
//
// Lightweight rule that fires an intervention when the *primary user*
// has been silent longer than a threshold, with an optional grace period
// if someone else spoke after the primary user (to avoid interrupting turn-taking).

import Foundation
import Combine

/// Fires `.longPause` when the primary user has been silent past a threshold.
final class PauseRuleTrigger {
    // MARK: - Configuration
    private let primaryUserID: String
    private let silenceThreshold: TimeInterval
    private let graceForOthers: TimeInterval
    private let tickInterval: TimeInterval
    private let cooldownAfterFire: TimeInterval

    // MARK: - Outputs
    private let eventsSubject = PassthroughSubject<InterventionEvent, Never>()
    var events: AnyPublisher<InterventionEvent, Never> { eventsSubject.eraseToAnyPublisher() }

    // MARK: - State
    private var lastPrimarySpeechAt: Date?
    private var lastAnySpeechAt: Date?
    private var lastFiredAt: Date?
    private var timer: Timer?

    // MARK: - Init
    /// - Parameters:
    ///   - primaryUserID: The diarization ID treated as the main participant to monitor.
    ///   - silenceThreshold: Seconds of silence from the primary user to trigger.
    ///   - graceForOthers: Extra seconds added to the threshold if others have spoken after the primary user.
    ///   - tickInterval: How often to evaluate silence.
    ///   - cooldownAfterFire: Minimum seconds between consecutive fires; re-arms sooner if the user speaks.
    init(
        primaryUserID: String,
        silenceThreshold: TimeInterval,
        graceForOthers: TimeInterval,
        tickInterval: TimeInterval = 0.5,
        cooldownAfterFire: TimeInterval = 3.0
    ) {
        self.primaryUserID = primaryUserID
        self.silenceThreshold = silenceThreshold
        self.graceForOthers = graceForOthers
        self.tickInterval = tickInterval
        self.cooldownAfterFire = cooldownAfterFire
        startTimer()
    }

    deinit { timer?.invalidate() }

    // MARK: - Input
    func receive(_ chunk: TranscriptChunk) {
        // Update the "any speech" clock on any non-empty text.
        if !chunk.isEmptyText {
            lastAnySpeechAt = max(lastAnySpeechAt ?? chunk.endAt, chunk.endAt)
            // Update the primary clock only when the primary user speaks with non-empty text.
            if chunk.speakerID == primaryUserID {
                lastPrimarySpeechAt = max(lastPrimarySpeechAt ?? chunk.endAt, chunk.endAt)
            }
        }
        // Re-arm immediately after the primary user speaks again
        // (so we can detect the next silence without waiting for cooldown).
        if chunk.speakerID == primaryUserID, !chunk.isEmptyText {
            lastFiredAt = nil
        }
    }

    func reset() {
        lastPrimarySpeechAt = nil
        lastAnySpeechAt = nil
        lastFiredAt = nil
    }

    // MARK: - Timer loop
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    private func tick() {
        let now = Date()

        // Require at least one primary utterance before we begin monitoring.
        guard let lastPrimary = lastPrimarySpeechAt else { return }

        // Respect cooldown between fires unless the user has spoken again (handled in receive()).
        if let lastFiredAt, now.timeIntervalSince(lastFiredAt) < cooldownAfterFire { return }

        // If someone else spoke after the primary user's last utterance, extend the threshold.
        var effectiveThreshold = silenceThreshold
        if let lastAny = lastAnySpeechAt, lastAny > lastPrimary {
            effectiveThreshold += graceForOthers
        }

        let silence = now.timeIntervalSince(lastPrimary)
        guard silence >= effectiveThreshold else { return }

        // Fire an intervention event and enter cooldown; will re-arm on next primary speech.
        lastFiredAt = now
        let event = InterventionEvent(
            at: now,
            reason: .longPause(duration: silence),
            context: [] // The orchestrating engine attaches recent context.
        )
        eventsSubject.send(event)

        // Optional: require the primary user to speak again before we consider another "silence".
        // This helps prevent repeated nudges during a single long quiet stretch.
        lastPrimarySpeechAt = nil
    }
}

