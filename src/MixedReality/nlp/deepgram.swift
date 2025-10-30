import AVFoundation
import Starscream

class SpeechProcesser {
    private let audioEngine = AVAudioEngine()
    // Used to process or convert audio before sending it somewhere
    private let converterNode = AVAudioMixerNode()
    // Used to collect audio or send it to speakers/network
    private let sinkNode = AVAudioMixerNode()
    
    init() {
        configureAudioEngine()
    }
    
    private func configureAudioEngine() {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        
        // Create an output format for the converter node
        let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: inputFormat.sampleRate,
            channels: inputFormat.channelCount,
            interleaved: true)
        
        audioEngine.attach(converterNode)
        audioEngine.attach(sinkNode)
        
        // Installing a "tap" allows us to read audio buffers in real-time as they pass through this node
        converterNode.installTap(onBus: 0, bufferSize: 1024, format: converterNode.outputFormat(forBus: 0)) {(
            buffer: AVAudioPCMBuffer!,
            time: AVAudioTime!) -> Void in
        }
        
        audioEngine.connect(inputNode, to: converterNode, format: inputFormat)
        audioEngine.connect(converterNode, to: sinkNode, format: outputFormat)
        audioEngine.prepare()
        
        do {
        try AVAudioSession.sharedInstance().setCategory(.record)
            try audioEngine.start()
        } catch {
            print(error)
        }
    }
}
