//
//  PromptService.swift
//  MixedReality
//

import Foundation
import Collections
import Combine
import OSLog

actor PromptService {
    private let logger = Logger(subsystem: "PromptService", category: "Services")
    
    private let artifacts: ArtifactService
    private let experiment: ExperimentModel
    private let llm: LLMService
    private let speechService: SpeechService
    
    private var summary = ""
    private var recentTranscript = Deque<TranscriptChunk>()

    private var pendingForSummary = Deque<TranscriptChunk>()
    private var isSummarizing = false

        private let maxSummaryChars = 900
    
    private static let systemPrompt = """
        You are a conversational support assistant for a mixed-reality environment that helps older adults continue conversations naturally.
    
        ### When a pause or hesitation occurs:
        1. If the user is struggling to recall a factual detail, you may provide the answer directly to prevent the conversation from stalling.
        2. If the question is opinion-based or reflective, do not answer for them. Instead, give gentle cues or reminders of the discussion so far to help them continue their own thought.
        3. If the conversation stops after a question was answered (i.e. an "awkward pause"), you may provide suggestions for how to continue the conversation.
    
        ### Response guidelines:
        1. Keep responses short (1 sentence), natural, and supportive.
        2. Avoid vague pronouns (e.g. it, that, they) and always reference the current topic clearly.
        3. Your role is to assist conversation flow - not to take control of it.
        4. Remember that the user is having a conversation with someone else, not you.
        5. Use phrasing like "you were talking about" instead of "you were asking about" because you do not know which speaker ID is the one viewing your prompts. 
    """

    private static let summarySystemPrompt = """
        You maintain a rolling summary of a two-person conversation to support later prompt generation.

        Requirements:
        - Keep it short and concrete (prefer 4-8 bullet points or a compact paragraph).
        - Preserve key nouns: people, places, activities, and open questions.
        - Do NOT invent details.
        - Focus on durable context (topics, facts, goals, emotional tone).
        - Output ONLY the updated summary text (no preamble).
    """
    
    init(artifacts: ArtifactService, experiment: ExperimentModel, llm: LLMService, miniLLM: LLMService, speechService: SpeechService) {
        self.artifacts = artifacts
        self.experiment = experiment
        self.llm = llm
        self.miniLLM = miniLLM
        self.speechService = speechService
    }
    
    func handleTranscriptChunk(chunk: TranscriptChunk) async {
        guard chunk.isFinal else { return }

        recentTranscript.insertSorted(chunk)

        // Maintain bounded window for prompt + summary logic (same existing behavior)
        if self.recentTranscript.count == self.experiment.promptContextWindow + self.experiment.summaryContextWindow {
            // Move the oldest N lines into the summary buffer (don’t lose them)
            let toSummarizeCount = self.experiment.summaryContextWindow
            let oldChunks = self.recentTranscript.prefix(toSummarizeCount)

            for c in oldChunks { 
                self.pendingForSummary.append(c) 
            }

            self.recentTranscript.removeFirst(toSummarizeCount)

            logger.info("Queued \(toSummarizeCount) lines for summary; pending=\(self.pendingForSummary.count)")
        }

        // Trigger summary update when enough pending chunks have accumulated
        if self.pendingForSummary.count >= self.experiment.summaryContextWindow {
            await self.updateSummaryIfNeeded()
        }
    }
    
    private func updateSummaryIfNeeded() async {
        guard !isSummarizing else { return }
        guard !pendingForSummary.isEmpty else { return }

        isSummarizing = true
        defer { isSummarizing = false }

        // Take a snapshot so we don’t block incoming transcript handling too long
        let block = Array(pendingForSummary)
        let blockText = await MainActor.run {
            block.map { $0.description }.joined(separator: "\n")
        }

        let userPrompt = """
        Current summary:
        \(summary.isEmpty ? "(none)" : summary)

        New transcript lines to incorporate:
        \(blockText)

        Return an updated rolling summary only.
        """

        do {
            let start = CFAbsoluteTimeGetCurrent()
            var newSummary = try await miniLLM.generate(
                systemPrompt: Self.summarySystemPrompt,
                userPrompt: userPrompt
            )
            let end = CFAbsoluteTimeGetCurrent()
            let duration = String(format: "%.1f", end - start)

            // Hard cap to prevent runaway growth (simple + effective)
            if newSummary.count > maxSummaryChars {
                newSummary = String(newSummary.prefix(maxSummaryChars))
            }

            self.summary = newSummary
            self.pendingForSummary.removeAll() // clear only after success
            await artifacts.logEvent(
                type: "Summary",
                message: "Updated summary (\(block.count) lines) (\(duration)s)"
            )

        } catch {
            logger.error("Failed to update summary: \(error.localizedDescription)")
            await artifacts.logEvent(
                type: "Summary",
                message: "FAILED to update summary: \(error.localizedDescription)"
            )
            // keep pendingForSummary for retry later
        }
    }


    func generatePrompt(eventId: UInt64) async -> String {
        logger.info("💡 Generating prompt #\(eventId) from \(self.recentTranscript.count) transcript lines")
        let snapshot = self.recentTranscript
        let recentText = await MainActor.run {
            snapshot.map { $0.description }.joined(separator: "\n")
        }

        let promptContext = """
            Rolling summary:
            \(summary.isEmpty ? "(none)" : summary)

            Recent transcript:
            \(recentText)
            """

        do {
            let start = CFAbsoluteTimeGetCurrent()
            let prompt = try await self.llm.generate(systemPrompt: Self.systemPrompt, userPrompt: promptContext)
            let end = CFAbsoluteTimeGetCurrent()
            let duration = String(format: "%.1f", end - start)
            await self.artifacts.logEvent(type: "Prompt", message: "(#\(eventId)) (\(duration)s delay) \"\(prompt)\"")
            return prompt
        } catch {
            logger.error("Failed to generate prompt: \(error.localizedDescription)")
            return "Failed to generate prompt."
        }
    }

}
