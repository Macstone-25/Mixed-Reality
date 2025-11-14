//
//  PromptGenerator.swift
//  MixedReality
//
//  Created by William Clubine on 2025-11-14.
//

import Foundation
import OSLog

class PromptGenerator {
    private let logger = Logger(subsystem: "NLP", category: "SpeechProcessor")
    private var appModel: AppModel
    
    init (appModel: AppModel) {
        self.appModel = appModel
    }
    
    public func generate(chunks: [TranscriptChunk]) {
        logger.info("Generating prompt from \(chunks.count) transcript chunks")
        self.appModel.prompt = "Demo"
    }
}
