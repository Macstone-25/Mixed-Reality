//
//  AudioAnonymizer.swift
//  MixedReality
//

import Foundation
import AVFoundation

protocol AudioAnonymizer {
    /// Takes the recorded conversation file, processes it, and returns the output URL.
    /// - Parameters:
    ///   - inputURL: The original recorded audio file
    ///   - artifacts: Used for logging and resolving output file URLs
    /// - Returns: The URL of the anonymized output file
    func anonymize(inputURL: URL, artifacts: ArtifactService) async throws -> URL
}
