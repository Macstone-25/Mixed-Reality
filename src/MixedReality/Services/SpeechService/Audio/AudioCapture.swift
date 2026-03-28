//
//  AudioCapture.swift
//  MixedReality
//

import AVFoundation

protocol AudioCapture {
    var inputFormat: AVAudioFormat { get }
    func requestPermission() async -> Bool
    func activateSession() throws
    func deactivateSession() throws
    func installTap(bufferSize: AVAudioFrameCount, handler: @escaping (AVAudioPCMBuffer, AVAudioTime) -> Void) throws
    func removeTap()
    func startEngine() throws
    func stopEngine()
    func resetEngine()
    var isEngineRunning: Bool { get }
    func startRecording(to url: URL) throws
    func stopRecording() async
    var recordingError: Error? { get }
    func append(_ sampleBuffer: CMSampleBuffer)
}
