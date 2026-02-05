//
//  SessionModel.swift
//  MixedReality
//

import Foundation
import Combine
import OSLog

enum PromptReadMethod: String, Sendable {
    case gaze = "Gaze"
    case button = "Button"
}

class SessionModel {
    let id: String
    
    private let logger = Logger(subsystem: "SessionModel", category: "Models")
    
    private let experiment: ExperimentModel
    private let artifacts: ArtifactService
    private let llm: LLMService
    private let miniLLM: LLMService
    private let speechService: SpeechService
    private let triggerService: TriggerService
    private let promptService: PromptService
    
    private var sinks = Set<AnyCancellable>()
    
    var onPrompt: ((String) -> (Void))?
    
    // MARK: - Prompt Tracking
    private var currentPromptEventId: UInt64?
    private var promptDisplayedAt: Date?
    private var promptReadAt: Date?
    private var promptReadMethod: PromptReadMethod?
    
    init(config: ConfigModel) async throws {
        // TODO: Add random id to display (#57)
        self.id = "Session"
        
        // TODO: Convert ExperimentModel to a .json file and store as an artifact (#47)
        self.experiment = try ExperimentModel(config: config)
        
        self.artifacts = try ArtifactService(id: id)
        self.llm = LLMService(artifacts: self.artifacts, experiment: experiment, llm: experiment.llm)
        self.miniLLM = LLMService(artifacts: self.artifacts, experiment: experiment, llm: experiment.miniLLM)
        self.speechService = try await SpeechService(artifacts: self.artifacts, experiment: experiment, config: DeepgramConfig())
        self.triggerService = await TriggerService(artifacts: self.artifacts, experiment: experiment, speechService: self.speechService, miniLLM: self.miniLLM)
        self.promptService = PromptService(artifacts: self.artifacts, experiment: experiment, llm: self.llm, speechService: self.speechService)
    }
    
    func start() async throws {
        await self.artifacts.logEvent(type: "Session", message: "Session starting...")
        await self.artifacts.logEvent(type: "Experiment", message: "\(experiment)")
        
        // Connect TriggerService to SpeechService
        sinks.insert(
            speechService.transcriptChunkEvent
                .sink { chunk in
                    Task { [weak self] in
                        guard let self = self else { return }
                        await self.triggerService.handleTranscriptChunk(chunk: chunk)
                    }
                }
        )
        
        // Connect PromptService to SpeechService
        sinks.insert(
            speechService.transcriptChunkEvent
                .sink { chunk in
                    Task { [weak self] in
                        guard let self = self else { return }
                        await self.promptService.handleTranscriptChunk(chunk: chunk)
                    }
                }
        )
        
        // Connect PromptService to TriggerService
        await self.triggerService.setOnTrigger { [weak self] event in
            Task {
                guard let self = self else { return }
                
                // TODO: Automatically clear prompt (#53) - make sure to use eventId to avoid clearing prompts overwriting this one
                let prompt = await self.promptService.generatePrompt(eventId: event.id)
                
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    guard let onPrompt = self.onPrompt else {
                        self.logger.warning("Dropping trigger \(event.id), no prompt callback set")
                        return
                    }
                    
                    // Set prompt tracking metadata
                    self.currentPromptEventId = event.id
                    self.promptDisplayedAt = Date()
                    self.promptReadAt = nil
                    self.promptReadMethod = nil
                    
                    onPrompt(prompt)
                }
            }
        }
        
        try await speechService.connect()
    }
    
    // MARK: - Prompt Read Tracking
    
    func logPromptRead(method: PromptReadMethod) {
        // Only log once per prompt
        guard let eventId = currentPromptEventId, promptReadAt == nil else { return }
        
        promptReadAt = Date()
        promptReadMethod = method
        
        let displayDuration = promptReadAt!.timeIntervalSince(promptDisplayedAt ?? Date())
        let message = "(#\(eventId)) method=\(method.rawValue) displayDuration=\(String(format: "%.2f", displayDuration))s"
        
        Task {
            await self.artifacts.logEvent(type: "PromptRead", message: message)
        }
    }
    
    func logPromptDismissed() {
        guard let eventId = currentPromptEventId else { return }
        
        let wasRead = promptReadAt != nil
        let method = promptReadMethod?.rawValue ?? "None"
        let message = "(#\(eventId)) wasRead=\(wasRead) method=\(method)"
        
        Task {
            await self.artifacts.logEvent(type: "PromptDismissed", message: message)
        }
        
        // Reset tracking state
        currentPromptEventId = nil
        promptDisplayedAt = nil
        promptReadAt = nil
        promptReadMethod = nil
    }
    
    func hasPromptBeenRead() -> Bool {
        return promptReadAt != nil
    }
    
    func end() async {
        await artifacts.logEvent(type: "Session", message: "Ending session...")
        await speechService.disconnect()
        await triggerService.stop()
        await artifacts.finalize()
    }
}
