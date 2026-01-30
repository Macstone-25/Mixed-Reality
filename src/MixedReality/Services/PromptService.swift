//
//  PromptService.swift
//  MixedReality
//
//  Created by William Clubine on 2026-01-30.
//

import Foundation
import Collections
import Combine
import OSLog

class PromptService {
    private let artifacts: ArtifactService
    private let experiment: ExperimentModel
    private let llm: LLMService
    private let speechService: SpeechService
    
    private let logger = Logger(subsystem: "PromptService", category: "Services")
    private var sinks = Set<AnyCancellable>()
    
    // TODO: Summarize old transcript lines
    private var summary = ""
    private var recentTranscript = Deque<String>()
    
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
    
    init(artifacts: ArtifactService, experiment: ExperimentModel, llm: LLMService, speechService: SpeechService) {
        self.artifacts = artifacts
        self.experiment = experiment
        self.llm = llm
        self.speechService = speechService
        sinks.insert(speechService.transcriptChunkEvent.sink(receiveValue: handleTranscriptChunk))
    }
    
    private func handleTranscriptChunk(chunk: TranscriptChunk) {
        guard (chunk.isFinal && chunk.isEmptyText) else { return }
        
        self.recentTranscript.append("[\(chunk.speakerID)] \(chunk.text.trimmingCharacters(in: .whitespacesAndNewlines))")
        
        // update summary when context is sufficiently large
        if (self.recentTranscript.count == self.experiment.promptContextWindow + self.experiment.summaryContextWindow) {
            let summaryContext = self.recentTranscript.prefix(self.experiment.summaryContextWindow).joined(separator: "\n")
            self.recentTranscript.removeFirst(self.experiment.summaryContextWindow)
            logger.info("Summarizing first \(self.experiment.summaryContextWindow) lines")
            // TODO: Summarize old transcript lines
        }
    }
    
    func generatePrompt(eventId: UUID) async -> String {
        let promptContext = self.recentTranscript.joined(separator: "\n")
        logger.info("💡 (\(eventId)) Generating prompt from \(self.recentTranscript.count) transcript lines")
        do {
            // TODO: Include old transcript summary
            let prompt = try await self.llm.generate(systemPrompt: Self.systemPrompt, userPrompt: promptContext)
            await self.artifacts.logEvent(type: "Prompt", message: "(\(eventId)) \"\(prompt)\"")
            return prompt
        } catch {
            logger.error("Failed to generate prompt: \(error.localizedDescription)")
            return "Failed to generate prompt."
        }
    }
}
