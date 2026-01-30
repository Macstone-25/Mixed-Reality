//
//  LLMGenerator.swift
//  MixedReality
//
//  Created by William Clubine on 2026-01-30.
//

protocol LLMGenerator {
    func generate(systemPrompt: String, userPrompt: String) async throws -> String
}
