//
//  TriggerService.swift
//  MixedReality
//

import Foundation
import Combine
import Collections
import OSLog

enum TriggerEvaluationStrategy: Hashable, Encodable {
    case pauseEvaluator
    case fillerEvaluator
    // TODO: support llm evaluation (use experiment.miniLLM)
}

class TriggerService {
    private let logger = Logger(subsystem: "TriggerService", category: "Services")
    
    private let artifacts: ArtifactService
    private let experiment: ExperimentModel
    private let speechService: SpeechService
    
    private let evaluators: [TriggerEvaluator]
    private var evaluatorContext = Deque<TranscriptChunk>()
    private var evaluationTask: Task<Void, Never>?
    private var sinks = Set<AnyCancellable>()
    
    var onTrigger: ((InterventionEvent) -> (Void))?
    private var nextEventId: UInt64 = 0
    
    init(artifacts: ArtifactService, experiment: ExperimentModel, speechService: SpeechService) {
        self.artifacts = artifacts
        self.experiment = experiment
        self.speechService = speechService
        
        self.evaluators = experiment.triggerEvaluationStrategies.map { strategy in
            switch(strategy) {
            case(.pauseEvaluator):
                return PauseEvaluator(experiment: experiment)
            case(.fillerEvaluator):
                return FillerEvaluator()
            }
        }
        
        for evaluator in evaluators {
            logger.info("Added evaluator: \(String(describing: type(of: evaluator)))")
        }

        sinks.insert(speechService.transcriptChunkEvent.sink(receiveValue: handleTranscriptChunk))
    }
    
    private func handleTranscriptChunk(chunk: TranscriptChunk) {
        // update context if this is a finalized chunk
        if chunk.isFinal {
            evaluatorContext.append(chunk)
            if evaluatorContext.count > experiment.triggerContext {
                _ = evaluatorContext.popFirst()
            }
        }
        
        // launch (or relaunch) evaluation
        evaluationTask?.cancel()
        evaluationTask = Task {
            do {
                // sleep to give the user a chance to speak more before potentially triggering
                try Task.checkCancellation()
                try await Task.sleep(nanoseconds: UInt64(experiment.triggerDelayMs) * 1_000_000)
                try Task.checkCancellation()
                
                // race all evaluators and take the first intervention reason found
                let interventionReason = await withTaskGroup(of: InterventionReason?.self) { group in
                    for evaluator in evaluators {
                        group.addTask { [weak self] in
                            guard let self = self else { return nil }
                            return await evaluator.evaluate(chunk: chunk, context: self.evaluatorContext)
                        }
                    }
                    
                    for await result in group {
                        if result != nil {
                            group.cancelAll()
                            return result
                        }
                    }
                    
                    return nil
                }
                
                // if no intervention reason was found or the task was cancelled, end the evaluation
                
                guard let reason = interventionReason else { return }
                try Task.checkCancellation()
                
                // if an intervention reason was found, we need to trigger an event
                
                guard let onTrigger = onTrigger else {
                    return logger.warning("No trigger callback set, dropping intervention event: \(reason)")
                }
                
                var context = Array(evaluatorContext)
                if chunk != context.last {
                    context.append(chunk)
                }
                
                let event = InterventionEvent(
                    id: nextEventId,
                    at: Date.now,
                    reason: reason,
                    context: context
                )
                nextEventId += 1
                
                onTrigger(event)
            } catch { }
        }
    }
}

