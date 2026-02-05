//
//  SoundService.swift
//  MixedReality
//
//  Created by Gregory Archer on 2026-02-05.
//

import AVFoundation
import OSLog

@MainActor
final class SoundService {
    private let logger = Logger(subsystem: "SoundService", category: "Services")
    private var dingPlayer: AVAudioPlayer?

    func prepareDing() {
        guard dingPlayer == nil else { return }
        guard let url = Bundle.main.url(forResource: "ding", withExtension: "wav") else {
            logger.error("ding.wav not found in bundle")
            return
        }

        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.volume = 0.25          // change volume here
            p.prepareToPlay()
            dingPlayer = p
        } catch {
            logger.error("Failed to init ding player: \(error.localizedDescription)")
        }
    }

    func playDing() {
        if dingPlayer == nil { prepareDing() }
        dingPlayer?.currentTime = 0
        dingPlayer?.play()
    }
}
