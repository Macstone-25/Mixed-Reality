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
    var maxPauseDetectionMs: Int = 6000
    
    var minTriggerEvaluators: Int = 1
    var selectedTriggerEvaluationStrategies: Set<TriggerEvaluationStrategy> = [
        .pauseEvaluator,
        .fillerEvaluator
    ]
    
    var selectedLLMs: Set<LLMConfig> = [
        .openAI(.gpt_4_1_mini)
    ]
    
    var selectedMiniLLMs: Set<LLMConfig> = [
        .openAI(.gpt_4_1_mini)
    ]
}

