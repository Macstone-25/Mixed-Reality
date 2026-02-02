//
//  LLMGenerator.swift
//  MixedReality
//

protocol LLMGenerator {
    func generate(systemPrompt: String, userPrompt: String) async throws -> String
}
