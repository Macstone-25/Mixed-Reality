//
//  SpeechEngine.swift
//  MixedReality
//

import Foundation
import AVFoundation
import Combine

enum SpeechEngines: String, Encodable, Decodable, CaseIterable {
    case deepgram = "Deepgram"
    case openai = "OpenAI Whisper"
}

protocol SpeechEngine: AnyObject {
    /// Fired whenever a transcript chunk is produced
    var transcriptChunkEvent: PassthroughSubject<TranscriptChunk, Never> { get }

    /// Called once during SpeechService.connect() — provider sets itself up
    func start() async throws

    /// Called once during SpeechService.disconnect() — provider cleans up
    func stop() async

    /// Called for every audio buffer captured by the microphone tap
    func processAudioBuffer(buffer: AVAudioPCMBuffer, time: AVAudioTime)
}
