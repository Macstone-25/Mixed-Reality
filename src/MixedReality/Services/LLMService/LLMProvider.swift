//
//  LLMProvider.swift
//  MixedReality
//

import Foundation

enum LLMProviderError: Error {
    case httpError(code: Int, body: String)
    case noResponse
}

protocol LLMProvider : LLMGenerator {
    associatedtype Model
    
    init(artifacts: ArtifactService, experiment: ExperimentModel, model: Model)
}
