//
//  LLMTriggerEvaluator.swift
//  MixedReality
//

import Foundation
import OSLog

private struct LLMTriggerDecision: Decodable {
    let shouldTrigger: Bool
    let rationale: String
    
    enum CodingKeys: String, CodingKey {
        case shouldTrigger = "should_trigger"
        case rationale
    }
}

final class LLMTriggerEvaluator: TriggerEvaluator {
    private let logger = Logger(subsystem: "LLMTriggerEvaluator", category: "Services")
    
    private let artifacts: ArtifactService?
    private let miniLLM: any LLMGenerator
    
    private static let systemPrompt = """
        You are a trigger evaluator for a mixed-reality conversation assistant.
        Decide whether a conversational support prompt should be generated now.
        
        Return strict JSON only with this schema:
        {"should_trigger": boolean, "rationale": "short reason"}
        
        Rules:
        - Set should_trigger=true only if hesitation, confusion, or a conversational stall is likely.
        - Set should_trigger=false if conversation appears to be progressing normally.
        - rationale must be concise and grounded in the provided transcript context.
        - Never include markdown, code fences, or extra keys.
    """
    
    init(artifacts: ArtifactService? = nil, miniLLM: any LLMGenerator) {
        self.artifacts = artifacts
        self.miniLLM = miniLLM
    }
    
    func evaluate(chunk: TranscriptChunk, context: [TranscriptChunk]) async -> InterventionReason? {
        guard chunk.isFinal else {
            return nil
        }
        
        var contextSnapshot = context
        if chunk != contextSnapshot.last {
            contextSnapshot.append(chunk)
        }
        
        guard !contextSnapshot.isEmpty else {
            return nil
        }
        
        let transcriptContext = contextSnapshot
            .map(\.description)
            .joined(separator: "\n")
        
        let userPrompt = """
            Recent finalized transcript context:
            \(transcriptContext)
            
            Respond with strict JSON only.
        """
        
        do {
            let rawDecision = try await miniLLM.generate(
                systemPrompt: Self.systemPrompt,
                userPrompt: userPrompt
            )
            
            guard let decision = Self.parseDecision(rawDecision) else {
                await logParseFailure(rawDecision)
                return nil
            }
            
            guard decision.shouldTrigger else {
                return nil
            }
            
            return .llmSuggested(rationale: Self.sanitizeRationale(decision.rationale))
        } catch is CancellationError {
            return nil
        } catch let error as URLError where error.code == .cancelled {
            return nil
        } catch {
            logger.warning("LLM evaluator failed: \(error.localizedDescription, privacy: .public)")
            if let artifacts {
                await artifacts.logEvent(type: "TriggerEvaluator", message: "LLM evaluator error: \(error.localizedDescription)")
            }
            return nil
        }
    }
    
    private func logParseFailure(_ rawDecision: String) async {
        let normalized = rawDecision
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let preview = String(normalized.prefix(200))
        
        logger.warning("Failed to parse LLM trigger decision: \(preview, privacy: .public)")
        if let artifacts {
            await artifacts.logEvent(type: "TriggerEvaluator", message: "LLM evaluator parse failure: \(preview)")
        }
    }
    
    private static func parseDecision(_ rawDecision: String) -> LLMTriggerDecision? {
        if let decoded = decodeDecision(rawDecision) {
            return decoded
        }
        
        let withoutFence = unwrapCodeFence(rawDecision)
        if let decoded = decodeDecision(withoutFence) {
            return decoded
        }
        
        guard let extractedJSON = extractFirstJSONObject(withoutFence) else {
            return nil
        }
        
        return decodeDecision(extractedJSON)
    }
    
    private static func decodeDecision(_ rawDecision: String) -> LLMTriggerDecision? {
        let data = Data(rawDecision.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        return try? JSONDecoder().decode(LLMTriggerDecision.self, from: data)
    }
    
    private static func unwrapCodeFence(_ rawDecision: String) -> String {
        let lines = rawDecision
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
        
        guard lines.count >= 3 else {
            return rawDecision
        }
        
        let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let lastLine = lines.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard firstLine.hasPrefix("```"), lastLine == "```" else {
            return rawDecision
        }
        
        return lines
            .dropFirst()
            .dropLast()
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func extractFirstJSONObject(_ rawDecision: String) -> String? {
        guard let firstBrace = rawDecision.firstIndex(of: "{"),
              let lastBrace = rawDecision.lastIndex(of: "}") else {
            return nil
        }
        
        guard firstBrace <= lastBrace else {
            return nil
        }
        
        return String(rawDecision[firstBrace...lastBrace]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private static func sanitizeRationale(_ rationale: String) -> String {
        let normalized = rationale
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        guard !normalized.isEmpty else {
            return "Mini LLM suggested an intervention."
        }
        
        return String(normalized.prefix(160))
    }
}
