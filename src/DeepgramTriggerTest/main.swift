//
//  main.swift — MixedReality CLI Tester
//

import Foundation
import AVFoundation

let app = AppModelCore(primary: "user", useLLM: true)

class CLIDelegate: SpeechProcessorDelegate {
    let app: AppModelCore

    init(app: AppModelCore) { self.app = app }

    func speechProcessor(_ processor: SpeechProcessor,
                         didReceiveChunk chunk: DeepgramTranscriptChunk) {

        print("🎤 Heard: [\(chunk.speakerID)] \(chunk.text)")
        app.speechProcessor(processor, didReceiveChunk: chunk)
    }
}

let delegate = CLIDelegate(app: app)
app.speechProcessor.delegate = delegate

print("🎧 Starting Deepgram microphone test…")
app.startSession()

RunLoop.main.run()
