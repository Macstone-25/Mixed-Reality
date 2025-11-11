// HeuristicLLM.swift
//
// MixedReality — Criteria 3 prototype: lightweight "LLM" gate
//
// A fast, offline heuristic that imitates an LLM verdict. It inspects the most
// recent transcript context to decide whether the previously detected pause
// likely warrants an intervention, factoring in the primary speaker.
//
// Use this while wiring a real LLM; it shares the same LLMEvaluator interface.

import Foundation

public struct HeuristicLLM: LLMEvaluator {
    public init() {}

    // Tunables
    private let maxPrimaryChunksToInspect = 3
    private let shortUtteranceWordCount = 3

    // Filler / hesitation tokens (case-insensitive).
    private let hesitationTokens: [String] = [
        "um", "uh", "erm", "hmm", "mm", "like", "you know", "uhh", "umm"
    ]

    public func shouldIntervene(
        context: [TranscriptChunk],
        primaryUserID: String
    ) async throws -> LLMVerdict {

        // Grab last few primary-user chunks (most recent first).
        let primaryRecent: [TranscriptChunk] =
            Array(
                context
                    .reversed()
                    .filter { $0.speakerID == primaryUserID && !$0.isEmptyText }
                    .prefix(maxPrimaryChunksToInspect)
            )


        // If we have no primary speech yet, don't intervene (engine should have guarded this already).
        guard let lastPrimary = primaryRecent.first else {
            return LLMVerdict(shouldIntervene: false, reason: "No primary-user speech in context.")
        }

        // Signals that *support* intervening:
        let endsWithQuestion = lastPrimary.text.trimmed().hasSuffix("?")
        let endsWithEllipsis = lastPrimary.text.trimmed().hasSuffix("...")
        let isShort = lastPrimary.text.wordCount <= shortUtteranceWordCount
        let hasHesitation = containsHesitation(in: primaryRecent.map(\.text))

        // Turn-taking check: if someone else spoke after the last primary utterance,
        // we become more conservative (likely normal conversation flow).
        let lastSpeakerID = context.last?.speakerID
        let othersSpokeAfterPrimary = (lastSpeakerID != nil && lastSpeakerID != primaryUserID)

        // Decision logic:
        // - Strong positive signals: hesitation, ellipsis, short/abandoned utterance, question left hanging.
        // - Negative signal: others speaking after primary (likely normal exchange).
        // We intervene if positive signals exist OR if nobody else has spoken since the user's last unsure turn.
        let positive =
            hasHesitation ||
            endsWithEllipsis ||
            (endsWithQuestion && isShort) ||
            (isShort && !othersSpokeAfterPrimary)

        if positive && !(othersSpokeAfterPrimary && !endsWithQuestion && !hasHesitation) {
            let reason = buildReason(
                endsWithQuestion: endsWithQuestion,
                endsWithEllipsis: endsWithEllipsis,
                isShort: isShort,
                hasHesitation: hasHesitation,
                othersSpokeAfterPrimary: othersSpokeAfterPrimary
            )
            return LLMVerdict(shouldIntervene: true, reason: reason)
        } else {
            return LLMVerdict(shouldIntervene: false, reason: "Recent turn-taking suggests normal flow.")
        }
    }

    // MARK: - Helpers

    private func containsHesitation(in texts: [String]) -> Bool {
        let lower = texts.joined(separator: " ").lowercased()
        // Quick check for tokens or trailing ellipsis.
        if lower.contains("...") { return true }
        for token in hesitationTokens {
            if lower.contains(" \(token) ") || lower.hasPrefix(token + " ") || lower.hasSuffix(" " + token) {
                return true
            }
        }
        return false
    }

    private func buildReason(
        endsWithQuestion: Bool,
        endsWithEllipsis: Bool,
        isShort: Bool,
        hasHesitation: Bool,
        othersSpokeAfterPrimary: Bool
    ) -> String {
        var parts: [String] = []
        if hasHesitation { parts.append("Detected hesitation") }
        if endsWithEllipsis { parts.append("Incomplete thought (ellipsis)") }
        if endsWithQuestion { parts.append("Unanswered question") }
        if isShort { parts.append("Very short utterance") }
        if othersSpokeAfterPrimary { parts.append("Despite others speaking, user may need support") }
        return parts.isEmpty ? "Pause likely indicates user may need a nudge." : parts.joined(separator: "; ") + "."
    }
}

// MARK: - Small string utilities (file-local)

private extension String {
    func trimmed() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var wordCount: Int {
        trimmed().split { $0.isWhitespace || $0.isNewline }.count
    }
}
