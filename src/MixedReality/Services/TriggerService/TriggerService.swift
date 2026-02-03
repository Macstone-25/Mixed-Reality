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

actor TriggerService {
    private let logger = Logger(subsystem: "TriggerService", category: "Services")
    
    private let artifacts: ArtifactService
    private let experiment: ExperimentModel
    private let speechService: SpeechService
    private let miniLLM: LLMService
    
    private let evaluators: [TriggerEvaluator]
    private var evaluatorContext = Deque<TranscriptChunk>()
    private var evaluationTask: Task<Void, Never>?
    
    private var onTrigger: (@Sendable (InterventionEvent) -> (Void))?
    private var nextEventId: UInt64 = 1
    private var lastEventAt: Date = Date.distantPast
    private var lastChunk: TranscriptChunk?
    
    init(artifacts: ArtifactService, experiment: ExperimentModel, speechService: SpeechService, miniLLM: LLMService) async {
        self.artifacts = artifacts
        self.experiment = experiment
        self.speechService = speechService
        self.miniLLM = miniLLM
        
        self.evaluators = await MainActor.run {
            experiment.triggerEvaluationStrategies.map { strategy in
                switch strategy {
                case .pauseEvaluator:
                    return PauseEvaluator(experiment: experiment)
                case .fillerEvaluator:
                    return FillerEvaluator()
                }
            }
        }
        
        for evaluator in evaluators {
            logger.info("Added evaluator: \(String(describing: type(of: evaluator)))")
        }
    }
    
    func setOnTrigger(_ handler: @Sendable @escaping (InterventionEvent) -> Void) {
        self.onTrigger = handler
    }
    
    func getNextId(_ at: Date) -> UInt64 {
        nextEventId += 1
        lastEventAt = at
        return nextEventId - 1
    }
    
    func handleTranscriptChunk(chunk: TranscriptChunk) {
        // update context if this is a finalized chunk
        if chunk.isFinal {
            evaluatorContext.append(chunk)
            if evaluatorContext.count > experiment.triggerContext {
                _ = evaluatorContext.popFirst()
            }
        }
        
        // people usually pause to read prompts when they appear, so to avoid
        // double firing we need to have a cooldown period between triggers
        guard Date.now.timeIntervalSince(lastEventAt) >= experiment.triggerCooldown else {
            return
        }
        
        // sometimes deepgram hesitates (1-2 seconds) to mark a chunk as final and will
        // "spam" the same chunk without any refinement during that period. we want to
        // ignore chunks without change to avoid unnecessarily delaying our triggers.
        if chunk.text == lastChunk?.text && abs(chunk.endAt - (lastChunk?.endAt ?? 0)) < 0.5 {
            return
        }
        lastChunk = chunk
        
        // launch (or relaunch) evaluation
        var chunkContext = Array(evaluatorContext)
        evaluationTask?.cancel()
        evaluationTask = Task { [weak self] in
            do {
                // sleep to give the user a chance to speak more before potentially triggering
                try Task.checkCancellation()
                try await Task.sleep(nanoseconds: UInt64(self?.experiment.triggerDelayMs ?? 0) * 1_000_000)
                try Task.checkCancellation()
                
                // race all evaluators and take the first intervention reason found
                let interventionReason = await withTaskGroup(of: InterventionReason?.self) { [weak self] group in
                    guard let evaluators = await self?.evaluators else { return InterventionReason?(nil) }
                    
                    for evaluator in evaluators {
                        group.addTask {
                            return await evaluator.evaluate(chunk: chunk, context: chunkContext)
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
                let reasonString = await MainActor.run { reason.description }
                try Task.checkCancellation()
                
                // if an intervention reason was found, we need to trigger an event
                
                if chunk != chunkContext.last {
                    chunkContext.append(chunk)
                }
                
                let at = Date.now
                guard let id = await self?.getNextId(at) else { return }
                try Task.checkCancellation()
                
                let event = InterventionEvent(
                    id: id,
                    at: at,
                    reason: reason,
                    context: chunkContext
                )
                
                let message = "(#\(event.id)) \(reasonString) @ \(String(format: "%.1f", chunk.endAt))s"
                await self?.artifacts.logEvent(type: "Intervention", message: message)
                try Task.checkCancellation()
                
                guard let onTrigger = await self?.onTrigger else {
                    self?.logger.warning("No trigger callback set, dropping intervention event: \(reasonString)")
                    return
                }
                try Task.checkCancellation()
                onTrigger(event)
            } catch { }
        }
    }
    
    func stop() {
        evaluationTask?.cancel()
        onTrigger = nil
        logger.info("🛑 TriggerService stopped")
    }
}

