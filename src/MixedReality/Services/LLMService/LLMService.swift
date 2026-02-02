//
//  LLMServiceProtocol.swift
//  MixedReality
//

import Foundation
import OSLog

enum LLMConfig: Hashable, Encodable {
    case openAI(OpenAIModel)
}

class LLMService : LLMGenerator {
    private let artifacts: ArtifactService
    private let experiment: ExperimentModel
    private let llmProvider: any LLMProvider
    
    private let logger = Logger(subsystem: "LLMService", category: "Services")
    
    init(artifacts: ArtifactService, experiment: ExperimentModel, llm: LLMConfig) {
        self.artifacts = artifacts
        self.experiment = experiment
        
        switch llm {
        case .openAI(let model):
            self.llmProvider = OpenAIProvider(artifacts: artifacts, experiment: experiment, model: model)
        }
    }
    
    func generate(systemPrompt: String, userPrompt: String) async throws -> String {
        do {
            return try await llmProvider.generate(systemPrompt: systemPrompt, userPrompt: userPrompt)
        } catch {
            await artifacts.logEvent(type: "LLM", message: "Error: \(error.localizedDescription)")
            throw error
        }
    }
}
