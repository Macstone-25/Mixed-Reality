//
//  LLMProvider.swift
//  MixedReality
//
//  Created by William Clubine on 2026-01-30.
//

import Foundation

protocol LLMProvider : LLMGenerator {
    associatedtype Model
    
    init(artifacts: ArtifactService, experiment: ExperimentModel, model: Model)
}
