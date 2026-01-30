//
//  SpeechService.swift
//  MixedReality
//
//  Created by William Clubine on 2026-01-30.
//

import Foundation
import Combine

class SpeechService {
    private let artifacts: ArtifactService
    private let experiment: ExperimentModel
    
    let transcriptChunkEvent = PassthroughSubject<TranscriptChunk, Never>()
    
    init(artifacts: ArtifactService, experiment: ExperimentModel) {
        self.artifacts = artifacts
        self.experiment = experiment
    }
}
