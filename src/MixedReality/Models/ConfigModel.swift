//
//  ConfigModel.swift
//  MixedReality
//
//  Created by William Clubine on 2026-01-30.
//

import Foundation

enum LLMConfig: Hashable, Encodable {
    case openAI(OpenAIModel)
}

struct ConfigModel {
    var minimumPromptContextWindow: Int = 5
    var maximumPromptContextWindow: Int = 50
    
    var minimumSummaryContextWindow: Int = 3
    var maximumSummaryContextWindow: Int = 10
    
    var selectedLLMs: Set<LLMConfig> = [
        .openAI(.gpt_4_1_mini)
    ]
}

