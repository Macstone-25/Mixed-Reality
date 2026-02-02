//
//  DeepgramConfig.swift
//  MixedReality
//

import AVFoundation

struct DeepgramConfig {
    /// https://developers.deepgram.com/docs/model
    let model: String = "nova-3"
    
    /// https://developers.deepgram.com/docs/language
    let language: String = "en"
    
    /// https://developers.deepgram.com/docs/channels
    let channels: AVAudioChannelCount = 1
    
    /// https://developers.deepgram.com/docs/endpointing
    let endpointingMs: Int = 500
    
    /// https://developers.deepgram.com/docs/diarization
    let diarize: Bool = true
    
    /// https://developers.deepgram.com/docs/punctuation
    let punctuate: Bool = true
    
    /// https://developers.deepgram.com/docs/filler-words
    let fillerWords: Bool = true
    
    /// https://developers.deepgram.com/docs/interim-results
    let interimResults: Bool = true
    
    /// https://developers.deepgram.com/docs/speech-started
    /// Note: VAD messages are currently ignored by SpeechService
    let vadEvents: Bool = false
}
