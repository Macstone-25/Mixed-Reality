//
//  OpenAIConfig.swift
//  MixedReality
//

import Foundation

struct OpenAIConfig {
    /// The Realtime model to use
    /// https://platform.openai.com/docs/guides/realtime
    let model: String = "gpt-realtime"
    
    /// The voice for audio output
    /// https://platform.openai.com/docs/guides/realtime/audio
    let voice: String = "alloy"
    
    /// Instructions for the assistant
    /// Guides behavior of the transcription and responses
    let instructions: String = "You are a helpful assistant. Transcribe the user's speech accurately."
    
    /// Input audio format
    let inputAudioFormat: String = "pcm16"
    
    /// Output audio format
    let outputAudioFormat: String = "pcm16"
    
    /// Whether to include audio transcription using Whisper
    let transcriptionModel: String = "whisper-1"
    
    /// Turn detection (VAD) configuration
    /// https://platform.openai.com/docs/guides/realtime/voice-activity-detection
    let turnDetectionEnabled: Bool = true
    let turnDetectionType: String = "server_vad"
    let turnDetectionThreshold: Double = 0.5
    let turnDetectionPrefixPaddingMs: Int = 300
    let turnDetectionSilenceDurationMs: Int = 500
    
    /// Modalities supported in the session
    let modalities: [String] = ["text", "audio"]
    
    /// Estimated words per second for timing partial transcripts
    let wordsPerSecond: Double = 2.7
}
