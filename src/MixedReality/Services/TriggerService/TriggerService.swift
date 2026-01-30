//
//  TriggerService.swift
//  MixedReality
//
//  Created by William Clubine on 2026-01-30.
//

import Foundation

class TriggerService {
    private let artifacts: ArtifactService
    private let experiment: ExperimentModel
    private let speechService: SpeechService
    
    var onTrigger: ((InterventionEvent) -> (Void))?
    
    init(artifacts: ArtifactService, experiment: ExperimentModel, speechService: SpeechService) {
        self.artifacts = artifacts
        self.experiment = experiment
        self.speechService = speechService
    }
}
