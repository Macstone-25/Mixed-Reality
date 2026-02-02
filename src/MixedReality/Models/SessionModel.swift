//
//  SessionModel.swift
//  MixedReality
//
//  Created by William Clubine on 2026-01-30.
//

import Foundation
import OSLog

class SessionModel {
    let id: String
    
    private let logger = Logger(subsystem: "SessionModel", category: "Models")
    
    private let artifacts: ArtifactService
    private let llm: LLMService
    private let speechService: SpeechService
    private let triggerService: TriggerService
    private let promptService: PromptService
    
    var onPrompt: ((String) -> (Void))?
    
    init(experiment: ExperimentModel) async throws {
        // TODO: Add random id to display (#57)
        self.id = "Session"
        
        // TODO: Convert ExperimentModel to a .json file and store as an artifact (#47)
        self.artifacts = try ArtifactService(id: id)
        self.llm = LLMService(artifacts: self.artifacts, experiment: experiment)
        self.speechService = try await SpeechService(artifacts: self.artifacts, experiment: experiment, config: DeepgramConfig())
        self.triggerService = TriggerService(artifacts: self.artifacts, experiment: experiment, speechService: self.speechService)
        self.promptService = PromptService(artifacts: self.artifacts, experiment: experiment, llm: self.llm, speechService: self.speechService)
        
        await self.artifacts.logEvent(type: "Session", message: "Session Starting")
        
        self.triggerService.onTrigger = { [weak self] event in
            guard (self?.onPrompt != nil) else {
                self?.logger.warning("Dropping trigger \(event.id), no prompt callback set")
                return
            }
            
            Task {
                let prompt = await self?.promptService.generatePrompt(eventId: event.id)
                self?.onPrompt?(prompt ?? "")
                // TODO: Automatically clear prompt (#53) - make sure to use eventId to avoid clearing prompts overwriting this one
            }
        }
    }
}
