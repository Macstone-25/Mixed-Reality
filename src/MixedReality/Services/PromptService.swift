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
    private let miniLLM: LLMService
    private let speechService: SpeechService
    
    private var recentTranscript = Deque<TranscriptChunk>()
    
    private var summary = ""
    private var pendingSummarization = Deque<TranscriptChunk>()
    private var isSummarizing = false
    
    private static let systemPrompt = """
        You are an assistant that helps older adults continue conversations naturally when they lose their train of thought, are struggling to remember something, or otherwise get stuck.
        
        You will be provided with the most recent lines of the conversation transcript, along with a summary of the conversation from before the available transcript lines. The recency of transcript lines should be a main factor in deciding the topics to follow, more recent transcript lines should be weighed more than the summary when generating a prompt. Based on this, you must generate a prompt that will be shown to the user to help guide them.
        
        Each transcript line will be formatted with a speaker ID followed by the spoken words. The speaker ID can help guide you to understand the conversation, but must not be relied upon, as it is simply a guess at who is speaking and is usually wrong. To avoid confusion, do not refer to any specific speaker, and try to use phrasing like "you were talking about" instead of "you were asking" because you do not know which speaker is truly asking and which is answering.
        
        When generating a prompt for the user, follow these formatting rules:
        1. Your reply will be shown directly to the user, so you must generate only the prompt without any preamble.
        2. Keep responses short (85 characters max), natural, and supportive.
        3. Avoid vague pronouns (e.g. it, that, they) and always reference the current topic clearly.
        4. Never mention pauses, hesitations, or the system itself. Meta language breaks the natural flow of conversation.
        5. Never simply repeat, restate, or lightly paraphrase the most recent transcript line.
        6. Never output a bare greeting or acknowledgment that does not help move the conversation forward.
        7. If the recent transcript is only a short greeting or opener, suggest a natural next-step question or topic instead of echoing the greeting.
        8. Write the prompt as coaching text for the user, not as dialogue from one of the conversation participants.
        9. Prefer wording such as "You could ask...", "You could mention...", or "You were talking about...".
        10. Never answer as if you are one of the speakers in the transcript (for example, do not say things like "I'm good", "I've been alright", or "Thank you for asking").
        
        It is important that you do not fully take over the conversation, but some situations require more assistance than others. You must follow these guidelines to determine how direct of a prompt to provide:
        1. If the user is struggling to recall a factual detail, you may provide the answer directly to prevent the conversation from stalling.
        2. If the question is opinion-based or reflective, do not answer for them. Instead, give gentle cues or reminders of the discussion so far to help them continue with their own thoughts.
        3. If the conversation stops after a question was answered (i.e. an "awkward pause"), you may provide suggestions for how to continue the conversation (e.g. with an idea for a new topic to discuss).
        4. If the participants are becoming frustrated or tense, you may provide suggestions that gently guide the user to get the conversation back on track.
        
        Finally, it is very important to remember that you are not a participant in the conversation, only a guide. You must not refer to yourself, you must not answer questions about yourself, and you must not ask the user how or if they would like to be prompted, you are only allowed to reply with an actual prompt that follows the guidelines above.
        """

    private static let summarySystemPrompt = """
        You maintain a rolling summary of a conversation transcript to reduce the context window for larger LLMs.
        Requirements:
        - Keep it short and concrete (prefer 4-8 bullet points or a compact paragraph).
        - Preserve key nouns: people, places, activities, and open questions.
        - Do NOT invent details.
        - Focus on durable context like topics, facts, goals, and emotional tone.
        - Output ONLY the updated summary text (no preamble).
        - Summarize topics in chronological order so that it will be easier to discard stale information in future summary updates.
        - Do not reference speaker numbers, as these are volatile and inaccurate.
        """

    private static let retrySystemPrompt = """
        Your previous draft was invalid because it sounded like dialogue from one of the speakers instead of coaching text for the user.

        Retry and follow these extra rules:
        - Start with coaching language such as "You could..." or "You were talking about...".
        - Do not greet anyone.
        - Do not use first-person dialogue such as "I", "I'm", "I've", "my", "me", "we", or "our".
        - Do not repeat or closely paraphrase the transcript.
        - Output only one sentence of coaching text.
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

        // update summary when context is sufficiently large
        if self.recentTranscript.count == self.experiment.promptContextWindow + self.experiment.summaryContextWindow {
            let newSummaryContext = recentTranscript.prefix(experiment.summaryContextWindow)
            pendingSummarization.append(contentsOf: newSummaryContext)
            recentTranscript.removeFirst(experiment.summaryContextWindow)
            if !isSummarizing { await updateSummary() }
        }
    }
    
    private func updateSummary() async {
        guard !isSummarizing else { return }
        isSummarizing = true
        defer { isSummarizing = false }

        while !pendingSummarization.isEmpty {
            let summaryContextChunks = Array(pendingSummarization)
            pendingSummarization.removeAll()
            
            let summaryContext = await MainActor.run {
                summaryContextChunks.map { $0.description }.joined(separator: "\n")
            }
            
            logger.info("Summarizing \(summaryContextChunks.count) transcript chunks...")
            
            let userPrompt = """
                Current summary:
                \(summary.isEmpty ? "(none)" : summary)
                
                New transcript lines to incorporate:
                \(summaryContext)
                
                Return an updated summary only.
                """
            
            do {
                let start = CFAbsoluteTimeGetCurrent()
                // TODO: consider adding configurations to cut this off after some length
                self.summary = try await miniLLM.generate(
                    systemPrompt: Self.summarySystemPrompt,
                    userPrompt: userPrompt
                )
                let end = CFAbsoluteTimeGetCurrent()
                let duration = String(format: "%.1f", end - start)
                await artifacts.logEvent(type: "Summary", message: "(\(duration)s delay) \"\(summary)\"")
            } catch {
                logger.error("Failed to update summary: \(error.localizedDescription)")
                await artifacts.logEvent(type: "Summary", message: "Failed to update summary: \(error.localizedDescription)")
            }
        }
    }

    func generatePrompt(eventId: UInt64) async -> String {
        logger.info("💡 Generating prompt #\(eventId) from \(self.recentTranscript.count) transcript lines")
        let snapshot = self.recentTranscript
        let recentLines = await MainActor.run {
            snapshot.map { $0.description }.joined(separator: "\n")
        }

        let promptContext = """
            Task:
            Generate one sentence of coaching text to help the user continue the conversation.
            Do not write the next line of dialogue as if you are one of the speakers.
            Do not answer the conversation yourself.

            Summary of Conversation:
            \(summary.isEmpty ? "(none)" : summary)

            Recent Transcript Lines:
            \(recentLines)
            """

        do {
            let start = CFAbsoluteTimeGetCurrent()
            let prompt = try await generateValidatedPrompt(promptContext: promptContext, transcriptSnapshot: Array(snapshot))
            let end = CFAbsoluteTimeGetCurrent()
            let duration = String(format: "%.1f", end - start)
            await self.artifacts.logEvent(type: "Prompt", message: "(#\(eventId)) (\(duration)s delay) \"\(prompt)\"")
            return prompt
        } catch {
            logger.error("Failed to generate prompt: \(error.localizedDescription)")
            return "Failed to generate prompt."
        }
    }

    private func generateValidatedPrompt(promptContext: String, transcriptSnapshot: [TranscriptChunk]) async throws -> String {
        let firstAttempt = try await self.llm.generate(
            systemPrompt: Self.systemPrompt,
            userPrompt: promptContext
        )

        guard shouldRetryPrompt(firstAttempt, transcriptSnapshot: transcriptSnapshot) else {
            return firstAttempt
        }

        await self.artifacts.logEvent(
            type: "Prompt",
            message: "Rejected participant-style prompt draft; retrying with stricter coaching instructions"
        )

        let retryUserPrompt = """
            \(promptContext)

            Rejected draft:
            \(firstAttempt)

            Generate a replacement that follows all instructions.
            """

        return try await self.llm.generate(
            systemPrompt: Self.systemPrompt + "\n\n" + Self.retrySystemPrompt,
            userPrompt: retryUserPrompt
        )
    }

    private func shouldRetryPrompt(_ prompt: String, transcriptSnapshot: [TranscriptChunk]) -> Bool {
        let normalizedPrompt = normalizeText(prompt)
        guard !normalizedPrompt.isEmpty else { return true }

        let firstPersonMarkers = [
            " i ",
            " i'm ",
            " ive ",
            " i've ",
            " i'd ",
            " i'll ",
            " my ",
            " me ",
            " we ",
            " our "
        ]

        let paddedPrompt = " \(normalizedPrompt) "
        if firstPersonMarkers.contains(where: { paddedPrompt.contains($0) }) {
            return true
        }

        let greetingPrefixes = [
            "hello",
            "hi",
            "good morning",
            "good afternoon",
            "good evening"
        ]
        if greetingPrefixes.contains(where: { normalizedPrompt.hasPrefix($0) }) {
            return true
        }

        let recentTexts = transcriptSnapshot.map { normalizeText($0.text) }.filter { !$0.isEmpty }
        if recentTexts.contains(where: { $0 == normalizedPrompt || $0.contains(normalizedPrompt) || normalizedPrompt.contains($0) }) {
            return true
        }

        if recentTexts.contains(where: { tokenOverlap(normalizedPrompt, $0) >= 0.7 }) {
            return true
        }

        return false
    }

    private func normalizeText(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func tokenOverlap(_ lhs: String, _ rhs: String) -> Double {
        let lhsTokens = Set(lhs.split(separator: " ").map(String.init))
        let rhsTokens = Set(rhs.split(separator: " ").map(String.init))
        guard !lhsTokens.isEmpty, !rhsTokens.isEmpty else { return 0 }

        let intersection = lhsTokens.intersection(rhsTokens).count
        return Double(intersection) / Double(min(lhsTokens.count, rhsTokens.count))
    }

}
