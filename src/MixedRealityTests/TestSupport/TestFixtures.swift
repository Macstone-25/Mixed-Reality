import Foundation
@testable import MRCS

func makeChunk(
    text: String,
    speaker: String = "0",
    isFinal: Bool = true,
    start: Double = 0.0,
    end: Double = 0.5
) -> TranscriptChunk {
    TranscriptChunk(
        text: text,
        speakerID: speaker,
        isFinal: isFinal,
        startAt: start,
        endAt: end
    )
}

func makeConfig(
    triggerDelayMs: Int = 0,
    pauseDurationMs: Int = 0,
    triggerContext: Int = 5,
    triggerCooldownMs: Int = 0,
    minTriggerEvaluators: Int = 1,
    selectedStrategies: Set<TriggerEvaluationStrategy> = [.pauseEvaluator]
) -> ConfigModel {
    var config = ConfigModel.default

    config.minPromptContextWindow = 5
    config.maxPromptContextWindow = 5
    config.minSummaryContextWindow = 3
    config.maxSummaryContextWindow = 3

    config.minTriggerContext = triggerContext
    config.maxTriggerContext = triggerContext

    config.minTriggerDelayMs = triggerDelayMs
    config.maxTriggerDelayMs = triggerDelayMs

    config.minPauseDetectionMs = pauseDurationMs
    config.maxPauseDetectionMs = pauseDurationMs

    config.minTriggerCooldownMs = triggerCooldownMs
    config.maxTriggerCooldownMs = triggerCooldownMs

    config.minTriggerEvaluators = minTriggerEvaluators
    config.selectedTriggerEvaluationStrategies = selectedStrategies

    config.selectedLLMs = [.openAI(.gpt_4_1)]
    config.selectedMiniLLMs = [.openAI(.gpt_4_1_mini)]

    return config
}

func makeExperiment(
    triggerDelayMs: Int = 0,
    pauseDurationMs: Int = 0,
    triggerContext: Int = 5,
    triggerCooldownMs: Int = 0,
    minTriggerEvaluators: Int = 1,
    selectedStrategies: Set<TriggerEvaluationStrategy> = [.pauseEvaluator]
    ) throws -> ExperimentModel {
    try ExperimentModel(
        config: makeConfig(
            triggerDelayMs: triggerDelayMs,
            pauseDurationMs: pauseDurationMs,
            triggerContext: triggerContext,
            triggerCooldownMs: triggerCooldownMs,
            minTriggerEvaluators: minTriggerEvaluators,
            selectedStrategies: selectedStrategies
        )
    )
}

func makeConfigWithEmptyLLMs() -> ConfigModel {
    var config = makeConfig()
    config.selectedLLMs = []
    return config
}

func makeConfigWithEmptyMiniLLMs() -> ConfigModel {
    var config = makeConfig()
    config.selectedMiniLLMs = []
    return config
}

func makeConfigWithEmptyTriggerStrategies() -> ConfigModel {
    var config = makeConfig()
    config.selectedTriggerEvaluationStrategies = []
    return config
}

func makeConfigForClampedTriggerEvaluators() -> ConfigModel {
    var config = makeConfig(
        minTriggerEvaluators: 5,
        selectedStrategies: [.pauseEvaluator]
    )
    config.minTriggerEvaluators = 5
    return config
}
