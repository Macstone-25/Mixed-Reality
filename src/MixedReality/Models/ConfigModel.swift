//
//  ConfigModel.swift
//  MixedReality
//
//  Created by William Clubine on 2026-01-30.
//

import Foundation

enum LLMConfig: Hashable {
    case openAI(OpenAIModel)
}

struct ConfigModel {
    var minimumPromptContextWindow = 5
    var maximumPromptContextWindow = 50
    
    var minimumSummaryContextWindow = 3
    var maximumSummaryContextWindow = 10
    
    var selectedLLMs: Set<LLMConfig> = [
        .openAI(.gpt_4_1_mini)
    ]
}

