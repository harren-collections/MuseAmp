//
//  AudioFileValidationError.swift
//  MuseAmpDatabaseKit
//
//  Created by @Lakr233 on 2026/06/12.
//

import Foundation

/// A deterministic verdict that an audio file is invalid and safe to prune.
/// Transient failures (I/O errors, locked file protection) must throw other
/// error types so callers keep the file on disk.
public enum AudioFileValidationError: Error, LocalizedError, Sendable, Equatable {
    case unreadable(reason: String)
    case notPlayable(reason: String)
    case durationOutOfRange(TimeInterval)

    public static let minimumDurationSeconds: TimeInterval = 1
    public static let maximumDurationSeconds: TimeInterval = 24 * 60 * 60

    public static func isDurationValid(_ seconds: TimeInterval) -> Bool {
        seconds.isFinite
            && seconds > minimumDurationSeconds
            && seconds < maximumDurationSeconds
    }

    public var errorDescription: String? {
        switch self {
        case let .unreadable(reason):
            String(localized: "Audio file is not readable: \(reason)", bundle: .module)
        case let .notPlayable(reason):
            String(localized: "Audio file cannot be played: \(reason)", bundle: .module)
        case let .durationOutOfRange(seconds):
            String(localized: "Audio duration \(Int(seconds)) seconds is outside the supported range", bundle: .module)
        }
    }
}
