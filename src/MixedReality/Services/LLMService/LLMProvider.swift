//
//  LLMProvider.swift
//  MixedReality
//

import Foundation

enum LLMProviderError : Error {
    case httpError(String)
}

protocol LLMProvider : LLMGenerator {
    associatedtype Model
    
    init(artifacts: ArtifactService, experiment: ExperimentModel, model: Model)
}
