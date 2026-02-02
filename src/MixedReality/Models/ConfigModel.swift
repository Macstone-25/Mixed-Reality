//
//  ConfigModel.swift
//  MixedReality
//

import Foundation

struct ConfigModel {
    var minPromptContextWindow: Int = 5
    var maxPromptContextWindow: Int = 50
    
    var minSummaryContextWindow: Int = 3
    var maxSummaryContextWindow: Int = 10
    
    var minTriggerContext: Int = 4
    var maxTriggerContext: Int = 10
    
    var minTriggerDelayMs: Int = 500
    var maxTriggerDelayMs: Int = 2000
    
    var minPauseDetectionMs: Int = 2000
    var maxPauseDetectionMs: Int = 5000
    
    var minTriggerCooldownMs: Int = 5000
    var maxTriggerCooldownMs: Int = 30000
    
    var minTriggerEvaluators: Int = 2
    var selectedTriggerEvaluationStrategies: Set<TriggerEvaluationStrategy> = [
        .pauseEvaluator,
        .fillerEvaluator
    ]
    
    var selectedLLMs: Set<LLMConfig> = [
        .openAI(.gpt_4_1),
        .openAI(.gpt_4_1_mini),
        .openAI(.gpt_5_2),
        // TODO: Complete OpenAI verification to unlock these (https://platform.openai.com/settings/organization/general)
        // .openAI(.gpt_5_mini),
    ]
    
    var selectedMiniLLMs: Set<LLMConfig> = [
        .openAI(.gpt_4_1_mini),
    ]
}

