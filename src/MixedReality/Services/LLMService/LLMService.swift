//
//  LLMService.swift
//  MixedReality
//

import Foundation
import OSLog

enum LLMConfig: Hashable, Codable {
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
        } catch is CancellationError {
            await artifacts.logEvent(type: "LLM", message: "Request cancelled")
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            await artifacts.logEvent(type: "LLM", message: "Request cancelled")
            throw CancellationError()
        } catch LLMProviderError.noResponse {
            await artifacts.logEvent(type: "LLM", message: "Connection Error: No response")
            throw LLMProviderError.noResponse
        } catch LLMProviderError.httpError(let code, let body) {
            await artifacts.logEvent(type: "LLM", message: "HTTP Error: (\(code)) \(body)")
            throw LLMProviderError.httpError(code: code, body: body)
        } catch {
            await artifacts.logEvent(type: "LLM", message: "Unknown Error: \(error.localizedDescription)")
            throw error
        }
    }
}
