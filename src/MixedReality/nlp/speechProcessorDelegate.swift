// Formatting for the delegate pattern
struct TranscriptChunk {
    let speakerID: String
    let start_time: Double?
    let end_time: Double?
    let text: String
}

// Delegate protocol
protocol SpeechProcessorDelegate: AnyObject {
    func speechProcessor(_ processor: SpeechProcessor, didReceiveChunk chunk: TranscriptChunk)
}
