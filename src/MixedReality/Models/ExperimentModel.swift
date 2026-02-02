//
//  ExperimentModel.swift
//  MixedReality
//

import Foundation

enum ExperimentError: Error {
    case insufficientOptions(String)
}

struct ExperimentModel: Encodable {
    /// Controls the LLM to be used for general tasks
    let llm: LLMConfig
    
    /// Controls the LLM to be used for high-frequency tasks
    let miniLLM: LLMConfig
    
    /// Controls the trigger evaluators to run
    let triggerEvaluationStrategies: [TriggerEvaluationStrategy]
    
    /// Determines how many lines of transcript are used for prompt generation
    let promptContextWindow: Int
    
    /// Determines how many lines of transcript are used for summary updates
    let summaryContextWindow: Int
    
    /// Determines how many lines of transcript are used as context for TriggerEvaluators
    let triggerContext: Int
    
    /// Determines how long the trigger engine waits to run evaluators (unless more transcript arrives)
    let triggerDelayMs: Int
    
    /// Determines the duration until a pause-based intervention
    let pauseDurationMs: Int
    
    init(config: ConfigModel) throws {
        guard let llm = config.selectedLLMs.randomElement() else {
            throw ExperimentError.insufficientOptions("No LLMs selected")
        }
        self.llm = llm
        
        guard let miniLLM = config.selectedMiniLLMs.randomElement() else {
            throw ExperimentError.insufficientOptions("No mini LLMs selected")
        }
        self.miniLLM = miniLLM
        
        guard !config.selectedTriggerEvaluationStrategies.isEmpty else {
            throw ExperimentError.insufficientOptions("No trigger evaluators selected")
        }
        let maxTriggerEvaluators = config.selectedTriggerEvaluationStrategies.count
        let minTriggerEvaluators = min(config.minTriggerEvaluators, maxTriggerEvaluators)
        let triggerEvaluators = Int.random(in: (minTriggerEvaluators...maxTriggerEvaluators))
        self.triggerEvaluationStrategies = Array(config.selectedTriggerEvaluationStrategies.shuffled().prefix(triggerEvaluators))
        
        self.promptContextWindow = Int.random(in: (config.minPromptContextWindow...config.maxPromptContextWindow))
        self.summaryContextWindow = Int.random(in: (config.minSummaryContextWindow...config.maxSummaryContextWindow))
        self.triggerContext = Int.random(in: (config.minTriggerContext...config.maxTriggerContext))
        self.triggerDelayMs = Int.random(in: (config.minTriggerDelayMs...config.maxTriggerDelayMs))
        self.pauseDurationMs = Int.random(in: (config.minPauseDetectionMs...config.maxPauseDetectionMs))
    }
}

