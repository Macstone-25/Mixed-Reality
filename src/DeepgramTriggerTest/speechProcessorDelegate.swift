// Formatting for the delegate pattern
struct DeepgramTranscriptChunk {
    let speakerID: String
    let start_time: Double?
    let end_time: Double?
    let text: String
    let isFinal: Bool?        // MUST be optional
}

// Delegate protocol
protocol SpeechProcessorDelegate: AnyObject {
    func speechProcessor(_ processor: SpeechProcessor, didReceiveChunk chunk: DeepgramTranscriptChunk)
}
