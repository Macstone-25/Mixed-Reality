//
//  ExperimentModel.swift
//  MixedReality
//
//  Created by William Clubine on 2026-01-30.
//

import Foundation

struct ExperimentModel {
    let llm: LLMConfig
    
    let promptContextWindow: Int
    let summaryContextWindow: Int
    
    init(config: ConfigModel) throws {
        guard !config.selectedLLMs.isEmpty else {
            throw NSError(domain: "ExperimentModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "No LLMs selected"])
        }
        self.llm = config.selectedLLMs.randomElement()!
        
        self.promptContextWindow = Int.random(in: (config.minimumPromptContextWindow...config.maximumPromptContextWindow))
        self.summaryContextWindow = Int.random(in: (config.minimumSummaryContextWindow...config.maximumSummaryContextWindow))
    }
}
