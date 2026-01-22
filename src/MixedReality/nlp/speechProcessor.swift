import AVFoundation
import Starscream
import os

// MARK: - Deepgram response model

struct DeepgramResponse: Codable {
    let is_final: Bool?
    let speech_final: Bool?
    let channel: Channel?

    struct Channel: Codable {
        let alternatives: [Alternative]?
    }

    struct Alternative: Codable {
        let transcript: String?
        let words: [Word]?
    }

    struct Word: Codable {
        let word: String
        let speaker: Int?
        let start: Double?
        let end: Double?
    }
}

/// Lightweight envelope so we can ignore non-"Results" frames
private struct DeepgramEnvelope: Decodable {
    let type: String?
}

class SpeechProcessor: WebSocketDelegate {
    public private(set) var conversation: [String: [String]] = [:]
    private let logger = Logger(subsystem: "NLP", category: "SpeechProcessor")

    private let audioEngine = AVAudioEngine()
    private let converterNode = AVAudioMixerNode()
    private let sinkNode = AVAudioMixerNode()

    private let sampleRate: Double
    private let channels: AVAudioChannelCount
    private let interleaved: Bool

    // Tune this (ms). Smaller -> finals arrive faster.
    private let endpointingMs: Int = 1500

    private let deepgramKey: String

    private lazy var socket: Starscream.WebSocket = {
        let urlString =
            "wss://api.deepgram.com/v1/listen" +
            "?model=nova-2" +
            "&diarize=true" +
            "&punctuate=true" +
            "&filler_words=true" +
            "&encoding=linear16" +
            "&interim_results=true" +
            "&endpointing=\(endpointingMs)" +
            "&vad_events=true" +
            "&sample_rate=\(Int(sampleRate))" +
            "&channels=\(channels)"

        guard let url = URL(string: urlString) else {
            fatalError("Invalid WebSocket URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Token \(deepgramKey)", forHTTPHeaderField: "Authorization")
        return Starscream.WebSocket(request: request)
    }()

    weak var delegate: SpeechProcessorDelegate?

    init(sampleRate: Double = 48_000, channels: AVAudioChannelCount = 1, interleaved: Bool = true) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.interleaved = interleaved

        guard let key = ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"] else {
            fatalError("Deepgram API Key not found.")
        }
        self.deepgramKey = key

        socket.delegate = self
        configureAudioSession()
        socket.connect()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()

        session.requestRecordPermission { granted in
            if !granted {
                self.logger.error("Microphone permission denied.")
                return
            }
            DispatchQueue.main.async {
                do {
                    try session.setCategory(.playAndRecord, options: [.duckOthers, .allowBluetooth])
                    try session.setMode(.measurement)
                    try session.setActive(true, options: [])
                    self.prepareAudioGraphAfterSessionActivation()
                } catch {
                    self.logger.error("Failed to configure AVAudioSession: \(error.localizedDescription)")
                }
            }
        }
    }

    private func prepareAudioGraphAfterSessionActivation() {
        let inputNode = audioEngine.inputNode
        let nativeFormat = inputNode.inputFormat(forBus: 0)

        let channelCount = nativeFormat.channelCount
        let sr = nativeFormat.sampleRate
        guard channelCount > 0, sr > 0 else {
            logger.error("Invalid native input format — channels: \(channelCount), sampleRate: \(sr)")
            return
        }

        audioEngine.attach(converterNode)
        audioEngine.attach(sinkNode)

        converterNode.installTap(onBus: 0, bufferSize: 1024, format: nativeFormat) { [weak self] buffer, _ in
            guard let self else { return }
            guard let pcmData = self.convertBufferToPCM16(buffer: buffer, targetChannelCount: 1) else { return }
            self.socket.write(data: pcmData)
        }

        audioEngine.connect(inputNode, to: converterNode, format: nativeFormat)
        audioEngine.connect(converterNode, to: sinkNode, format: nativeFormat)

        do {
            try audioEngine.start()
            logger.info("Audio engine started.")
        } catch {
            logger.error("Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    private func convertBufferToPCM16(buffer: AVAudioPCMBuffer, targetChannelCount: AVAudioChannelCount) -> Data? {
        let format = buffer.format
        let frameLength = Int(buffer.frameLength)
        let channels = Int(format.channelCount)

        guard format.commonFormat == .pcmFormatFloat32,
              let floatChannelData = buffer.floatChannelData else {
            return nil
        }

        var interleavedMono = [Int16]()
        interleavedMono.reserveCapacity(frameLength)

        for frameIndex in 0..<frameLength {
            var sampleSum: Float = 0.0
            for ch in 0..<channels {
                sampleSum += floatChannelData[ch][frameIndex]
            }
            let avg = sampleSum / Float(channels)
            let clipped = max(-1.0, min(1.0, avg))
            interleavedMono.append(Int16(clipped * Float(Int16.max)))
        }

        return interleavedMono.withUnsafeBufferPointer { ptr in
            Data(buffer: ptr)
        }
    }

    func didReceive(event: Starscream.WebSocketEvent, client: any Starscream.WebSocketClient) {
        switch event {
        case .connected(let headers):
            logger.info("WebSocket connected with headers: \(headers, privacy: .public)")
        case .disconnected(let reason, let code):
            logger.info("WebSocket disconnected. Reason: \(reason, privacy: .public), code: \(code)")
        case .text(let text):
            if let data = text.data(using: .utf8) {
                processJSON(data: data)
            }
        case .error(let error):
            if let error {
                logger.error("WebSocket error: \(error.localizedDescription, privacy: .public)")
            } else {
                logger.error("WebSocket error: unknown")
            }
        default:
            break
        }
    }

    public func processJSON(data: Data) {
        // ✅ Ignore non-Results frames so we don't spam decode errors and lose context.
        if let envelope = try? JSONDecoder().decode(DeepgramEnvelope.self, from: data),
           let type = envelope.type,
           type != "Results" {
            return
        }

        do {
            let response = try JSONDecoder().decode(DeepgramResponse.self, from: data)
            guard let alternatives = response.channel?.alternatives else { return }

            let finalFlag = response.speech_final ?? response.is_final ?? false

            for alt in alternatives {
                if let words = alt.words, !words.isEmpty {
                    var speakerSentences: [String: (text: String, start: Double?, end: Double?)] = [:]

                    for w in words {
                        let speakerID = w.speaker.map { "spk_\($0)" } ?? "user"
                        if var entry = speakerSentences[speakerID] {
                            entry.text += w.word + " "
                            entry.end = w.end
                            speakerSentences[speakerID] = entry
                        } else {
                            speakerSentences[speakerID] = (text: w.word + " ", start: w.start, end: w.end)
                        }
                    }

                    for (speakerID, entry) in speakerSentences {
                        let trimmed = entry.text.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { continue }

                        conversation[speakerID, default: []].append(trimmed)

                        let chunk = DeepgramTranscriptChunk(
                            speakerID: speakerID,
                            start_time: entry.start,
                            end_time: entry.end,
                            text: trimmed,
                            isFinal: finalFlag
                        )
                        delegate?.speechProcessor(self, didReceiveChunk: chunk)
                        logger.info("Speaker: \(speakerID, privacy: .public), Sentence: \(trimmed, privacy: .public)")
                    }
                } else if let transcript = alt.transcript?.trimmingCharacters(in: .whitespaces),
                          !transcript.isEmpty {
                    let speakerID = "user"
                    conversation[speakerID, default: []].append(transcript)

                    let chunk = DeepgramTranscriptChunk(
                        speakerID: speakerID,
                        start_time: nil,
                        end_time: nil,
                        text: transcript,
                        isFinal: finalFlag
                    )
                    delegate?.speechProcessor(self, didReceiveChunk: chunk)
                    logger.info("Speaker: \(speakerID, privacy: .public), Sentence: \(transcript, privacy: .public)")
                }
            }
        } catch {
            logger.error("Failed to decode Deepgram JSON: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func deconfigureAudioEngine() {
        conversation.removeAll()
        audioEngine.reset()
        audioEngine.stop()
        converterNode.removeTap(onBus: 0)
        socket.disconnect(closeCode: 1000)
        socket.delegate = nil
    }
}
