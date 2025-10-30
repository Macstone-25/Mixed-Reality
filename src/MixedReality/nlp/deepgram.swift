import AVFoundation
import Starscream

class SpeechProcesser {
    // Audio properties
    private let audioEngine = AVAudioEngine()
    private let converterNode = AVAudioMixerNode()
    private let sinkNode = AVAudioMixerNode()

    // Deepgram properties
    private let deepgramKey: String
    private lazy var socket: Starscream.WebSocket = {
        let url = URL(string: "wss://api.deepgram.com/v1/listen?encoding=linear16&sample_rate=48000&channels=1")!
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("Token \(deepgramKey)", forHTTPHeaderField: "Authorization")
        return Starscream.WebSocket(request: urlRequest)
    }()
    
    init() {
        // Load Deepgram API key from environment variables
        if let key = ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"] {
            self.deepgramKey = key
        } else {
            fatalError("Deepgram API Key not found.")
        }
        
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
            if let data = self.convertAudio(buffer: buffer) {
               self.socket.write(data: data)
            }
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
    
    public func deconfigureAudioEngine() {
        audioEngine.reset() // Clears connections between nodes
        audioEngine.stop()
        converterNode.removeTap(onBus: 0)
        socket.disconnect(closeCode: 1000)
    }
    
    private func convertAudio(buffer: AVAudioPCMBuffer) -> Data? {
      let audioBuffer = buffer.audioBufferList.pointee.mBuffers
      return Data(bytes: audioBuffer.mData!, count: Int(audioBuffer.mDataByteSize))
    }
}
