import AVFoundation
import Starscream
// TODO: Instead of printing use logging
// TODO: Update processJSON() for better transcription

// Formatting for the Deepgram response
struct DeepgramResponse: Codable {
  let isFinal: Bool?
  let channel: Channel?

  struct Channel: Codable {
     let alternatives: [Alternatives]?
  }

  struct Alternatives: Codable {
     let transcript: String?
  }
}

/*
  Handles audio format conversion, WebSocket lifecycle, and streaming.

  Inputs:
  - sampleRate: The audio sample rate in Hz (default: 48000)
  - channels: Number of audio channels (default: 1)
  - interleaved: Whether audio data is interleaved (true/false, default: true)
*/
class SpeechProcessor: WebSocketDelegate {
    // Audio properties
    private let audioEngine = AVAudioEngine()
    private let converterNode = AVAudioMixerNode()
    private let sinkNode = AVAudioMixerNode()
    
    // Audio format properties
    private let sampleRate: Double
    private let channels: AVAudioChannelCount
    private let interleaved: Bool
    private lazy var outputFormat: AVAudioFormat = {
        AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channels,
            interleaved: interleaved
        )!
    }()

    // Deepgram properties
    private let deepgramKey: String
    private lazy var socket: Starscream.WebSocket = {
        // Build URL dynamically based on audio format
        let urlString = "wss://api.deepgram.com/v1/listen?encoding=linear16&sample_rate=\(Int(sampleRate))&channels=\(channels)"
        guard let url = URL(string: urlString) else {
            fatalError("Invalid WebSocket URL")
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("Token \(deepgramKey)", forHTTPHeaderField: "Authorization")
        return Starscream.WebSocket(request: urlRequest)
    }()
    
    init(sampleRate: Double = 48000, channels: AVAudioChannelCount = 1, interleaved: Bool = true) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.interleaved = interleaved
        // Load Deepgram API key from environment variables
        if let key = ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"] {
            self.deepgramKey = key
        } else {
            fatalError("Deepgram API Key not found.")
        }
        
        socket.delegate = self // Allow SpeechProcessor to receive WebSocket information
        configureAudioEngine()
        socket.connect()
    }
    
    // Sets up the audio engine and tap to capture and stream live audio
    private func configureAudioEngine() {
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        
        audioEngine.attach(converterNode)
        audioEngine.attach(sinkNode)
        
        // Installing a "tap" allows us to read audio buffers in real-time as they pass through this node
        converterNode.installTap(onBus: 0, bufferSize: 1024, format: outputFormat) { buffer, time in
            if let data = self.convertAudio(buffer: buffer) {
                self.socket.write(data: data)
            }
        }
        
        audioEngine.connect(inputNode, to: converterNode, format: inputFormat)
        audioEngine.connect(converterNode, to: sinkNode, format: outputFormat)
        audioEngine.prepare()
        
        do {
        try audioEngine.start()
        } catch {
            print(error)
        }
    }
    
    // Converts audio buffer to raw PCM16 data for streaming
    private func convertAudio(buffer: AVAudioPCMBuffer) -> Data? {
        let audioBuffer = buffer.audioBufferList.pointee.mBuffers
        guard let mData = audioBuffer.mData else { return nil } // mData may be nil, so safely unwrap
        return Data(bytes: mData, count: Int(audioBuffer.mDataByteSize))
    }
    
    // Handles WebSocket events: connection, disconnection, incoming messages, and errors
    func didReceive(event: Starscream.WebSocketEvent, client: any Starscream.WebSocketClient) {
        switch event {
        case .connected(let headers):
            print("Connected: \(headers)")
        case .disconnected(let reason, let code):
            print("Disconnected: \(reason) code: \(code)")
        case .text(let text):
            // Convert to type data for JSONDecoder
            if let data = text.data(using: .utf8) {
                processJSON(data: data)
            }
        case .error(let error):
            print("WebSocket error: \(String(describing: error))")
        default:
            break
        }
    }
    
    // Parses Deepgram JSON and prints the transcript if present
    private func processJSON(data: Data) {
        do {
            let response = try JSONDecoder().decode(DeepgramResponse.self, from: data)
            if let transcript = response.channel?.alternatives?.first?.transcript {
                print("Transcript: \(transcript)")
            }
        } catch {
            print("Failed to decode Deepgram JSON: \(error)")
        }
    }
    
    // Cleans up audio engine and WebSocket, stopping all streaming activity
    public func deconfigureAudioEngine() {
        audioEngine.reset() // Clears connections between nodes
        audioEngine.stop()
        converterNode.removeTap(onBus: 0)
        socket.disconnect(closeCode: 1000)
        socket.delegate = nil
    }
}
