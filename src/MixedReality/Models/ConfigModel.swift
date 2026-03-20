//
//  ConfigModel.swift
//  MixedReality
//

import Foundation

struct ConfigModel: Codable {
    var minPromptContextWindow: Int = 5
    var maxPromptContextWindow: Int = 50
    
    var minSummaryContextWindow: Int = 3
    var maxSummaryContextWindow: Int = 10
    
    var minTriggerContext: Int = 4
    var maxTriggerContext: Int = 10
    
    var minTriggerDelayMs: Int = 500
    var maxTriggerDelayMs: Int = 2000
    
    var minPauseDetectionMs: Int = 2000
    var maxPauseDetectionMs: Int = 4000
    
    var minTriggerCooldownMs: Int = 5000
    var maxTriggerCooldownMs: Int = 30000
    
    var minTriggerEvaluators: Int = 2
    var selectedTriggerEvaluationStrategies: Set<TriggerEvaluationStrategy> = Set(TriggerEvaluationStrategy.allCases)
    
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
    
    var isDeleteEnabled: Bool = false
}

extension ConfigModel {
    static let `default` = ConfigModel()
    
    private static let storageKey = "ConfigModel.storage"

    func save() {
        let sanitized = sanitizedForCurrentModels()

        if let data = try? JSONEncoder().encode(sanitized) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    static func load() -> ConfigModel {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let config = try? JSONDecoder().decode(ConfigModel.self, from: data)
        else {
            return `default`
        }
        return config.sanitizedForCurrentModels()
    }

    private func sanitizedForCurrentModels() -> ConfigModel {
        var config = self
        let removedLargePro = config.selectedLLMs.contains(.google(.gemini_2_5_pro))
        let removedMiniPro = config.selectedMiniLLMs.contains(.google(.gemini_2_5_pro))

        config.selectedLLMs.remove(.google(.gemini_2_5_pro))
        config.selectedMiniLLMs.remove(.google(.gemini_2_5_pro))

        if removedLargePro && config.selectedLLMs.isEmpty {
            config.selectedLLMs = [.google(.gemini_2_5_flash)]
        }

        if removedMiniPro && config.selectedMiniLLMs.isEmpty {
            config.selectedMiniLLMs = [.google(.gemini_2_5_flash)]
        }

        return config
    }
}
