//
//  InterventionTriggering.swift
//  
//
//  Created by Mayowa Adesanya on 2025-11-05.
//
// MixedReality — Trigger pipeline API
//
// Public surface that other systems (prompt generation, UI, logging)
// use to feed transcript chunks and subscribe to intervention events.

import Foundation
import Combine

public protocol InterventionTriggering: AnyObject {
    /// Stream of intervention events the engine emits.
    var events: AnyPublisher<InterventionEvent, Never> { get }

    /// Feed new ASR transcript chunks into the engine.
    func receive(_ chunk: TranscriptChunk)

    /// Clear internal state (e.g., between study sessions).
    func reset()
}

