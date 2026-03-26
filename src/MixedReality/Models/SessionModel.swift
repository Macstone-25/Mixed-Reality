//
//  SessionModel.swift
//  MixedReality
//

import Combine
import Foundation
import OSLog
import AVFoundation

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
    private let soundService: SoundService
    
    private var sinks = Set<AnyCancellable>()
    
    var onPrompt: ((String) -> (Void))?
    
    private static let sessionNumberKey = "SessionModel.sessionNumber"
    
    init(config: ConfigModel) async throws {
        let sessionNumber = UserDefaults.standard.integer(forKey: Self.sessionNumberKey) + 1
        UserDefaults.standard.set(sessionNumber, forKey: Self.sessionNumberKey)
        self.id = "Session-\(String(format: "%03d", sessionNumber))"
        
        self.artifacts = try ArtifactService(id: id)
        self.experiment = try ExperimentModel(config: config)
        
        self.llm = LLMService(artifacts: self.artifacts, experiment: experiment, llm: experiment.llm)
        self.miniLLM = LLMService(artifacts: self.artifacts, experiment: experiment, llm: experiment.miniLLM)
        
        let speechEngine: any SpeechEngine
        switch experiment.speechEngine {
        case .openai:
            speechEngine = try OpenAIEngine(
                artifacts: artifacts,
                config: OpenAIConfig()
            )
        case .deepgram:
            speechEngine = try DeepgramEngine(
                artifacts: artifacts,
                config: DeepgramConfig()
            )
        }

        // Create the SpeechService with the chosen engine
        self.speechService = try await SpeechService(
            engine: speechEngine,
            artifacts: self.artifacts,
            experiment: experiment,
            anonymizer: PitchShiftAnonymizer(
                semitones: Float.random(in: -3 ... -2)
            ),
            capture: LiveAudioCapture()
        )
        
        self.triggerService = await TriggerService(artifacts: self.artifacts, experiment: experiment, speechService: self.speechService, miniLLM: self.miniLLM)
        self.soundService = SoundService()
        self.promptService = PromptService(artifacts: self.artifacts, experiment: experiment, llm: self.llm, miniLLM: self.miniLLM,  speechService: self.speechService)
    }
    
    func start() async throws {
        await self.artifacts.logEvent(type: "Session", message: "Session starting...")
        
        // Record the experiment config in a JSON file
        let experimentJson = try experiment.toJsonData()
        let experimentJsonHandle = try await artifacts.getFileHandle(name: "Experiment.json")
        try experimentJsonHandle.write(contentsOf: experimentJson)
        await artifacts.logEvent(type: "Session", message: "Experiment config saved as JSON")
        logger.info("\(String(describing: self.experiment))")
        
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

                    self.soundService.playDing()
                    onPrompt(prompt)
                }
            }
        }

        soundService.prepareDing()

        try await speechService.connect()
    }

    func restoreAfterForegrounding() async {
        await artifacts.logEvent(type: "Session", message: "Restoring session after app foreground")
        await triggerService.restoreAfterForegrounding()
        await speechService.reactivateIfNeeded()
    }
    
    func end() async {
        await artifacts.logEvent(type: "Session", message: "Ending session...")
        await speechService.disconnect()
        await triggerService.stop()
        await artifacts.finalize()
    }
}
