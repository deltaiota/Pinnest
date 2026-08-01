//
//  ClipboardWatcher.swift
//  Pinnest
//

import AppKit
import Observation

/// `NSPasteboard` posts no change notification, so the only way to keep the menu
/// item's enabled state honest is to watch `changeCount`. Comparing an integer twice
/// a second is far cheaper than decoding pasteboard contents, which only happens when
/// the count actually moves.
@MainActor
@Observable
final class ClipboardWatcher {
    private(set) var hasImage = false
    private var changeCount: Int

    init(pollInterval: TimeInterval = 0.5) {
        changeCount = NSPasteboard.general.changeCount
        hasImage = ClipboardImage.isImageAvailable()

        Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else {
                    timer.invalidate()
                    return
                }
                self.poll()
            }
        }
    }

    /// Re-reads the pasteboard even when the change count hasn't moved, for the moment
    /// just before acting on a menu click.
    func refresh() {
        changeCount = NSPasteboard.general.changeCount
        hasImage = ClipboardImage.isImageAvailable()
    }

    private func poll() {
        let current = NSPasteboard.general.changeCount
        guard current != changeCount else { return }
        changeCount = current
        hasImage = ClipboardImage.isImageAvailable()
    }
}
