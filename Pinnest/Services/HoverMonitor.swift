//
//  HoverMonitor.swift
//  Pinnest
//

import AppKit

/// Watches the pointer everywhere on screen.
///
/// A pin in piercing mode ignores mouse events, so it can never report hover itself —
/// and even a solid pin sees nothing while another app is frontmost. One process-wide
/// monitor serves every pin; the global variant covers other apps, the local one covers
/// Pinnest's own events, which the global monitor deliberately skips.
@MainActor
final class HoverMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(handler: @escaping (CGPoint) -> Void) {
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: events) { _ in
            MainActor.assumeIsolated { handler(NSEvent.mouseLocation) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: events) { event in
            MainActor.assumeIsolated { handler(NSEvent.mouseLocation) }
            return event
        }
    }

    deinit {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }
}
