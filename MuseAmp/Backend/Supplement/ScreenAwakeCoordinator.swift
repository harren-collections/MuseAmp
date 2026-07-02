//
//  ScreenAwakeCoordinator.swift
//  MuseAmp
//
//  Created by qaq on 2/7/2026.
//

import UIKit

/// Single owner of `UIApplication.isIdleTimerDisabled`. Features hold and
/// release named reasons instead of writing the global flag directly, so
/// concurrent holders cannot clobber each other. The system drops the flag
/// when the app is backgrounded, so the current state is re-applied every
/// time the app becomes active again.
@MainActor
final class ScreenAwakeCoordinator {
    enum Reason: String {
        case lyricsVisible
        case downloadsActive
        case syncSession
    }

    private var holdCounts: [Reason: Int] = [:]
    private nonisolated(unsafe) var didBecomeActiveObserver: NSObjectProtocol?

    init() {
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main,
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.applyCurrentState()
            }
        }
    }

    deinit {
        if let didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        }
    }

    func setActive(_ active: Bool, for reason: Reason) {
        if active {
            acquire(reason)
        } else {
            release(reason)
        }
    }

    func acquire(_ reason: Reason) {
        holdCounts[reason, default: 0] += 1
        logCurrentHolds(after: "acquire \(reason.rawValue)")
        applyCurrentState()
    }

    func release(_ reason: Reason) {
        guard let count = holdCounts[reason] else {
            AppLog.warning(self, "unbalanced release ignored reason=\(reason.rawValue)")
            return
        }
        holdCounts[reason] = count > 1 ? count - 1 : nil
        logCurrentHolds(after: "release \(reason.rawValue)")
        applyCurrentState()
    }

    private func logCurrentHolds(after action: String) {
        let holds = holdCounts
            .map { "\($0.key.rawValue)x\($0.value)" }
            .sorted()
            .joined(separator: ",")
        AppLog.info(self, "\(action) holds=[\(holds)]")
    }

    private func applyCurrentState() {
        UIApplication.shared.isIdleTimerDisabled = !holdCounts.isEmpty
    }
}
