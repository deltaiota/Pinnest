//
//  PinTestSupport.swift
//  PinnestTests
//

import AppKit
@testable import Pinnest

/// Shared fixtures for the suites that drive real pin windows inside the host app.
@MainActor
enum PinTest {
    static func image(width: Int, height: Int) -> NSImage {
        let image = NSImage(size: CGSize(width: width, height: height))
        image.lockFocus()
        NSColor.systemOrange.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        image.unlockFocus()
        return image
    }

    /// The window server's own hit-test rules, which honour `ignoresMouseEvents` —
    /// the oracle piercing is verified against.
    static func hitWindow(at point: CGPoint) -> Int {
        NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0)
    }

    static func panel(of controller: PinController) -> NSWindow? {
        NSApp.windows
            .first { $0 is PinPanel && $0.isVisible && $0.frame.size == controller.state.displaySize }
    }

    static func settle(_ seconds: Double = 0.25) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    /// Polls AppKit state instead of assuming a fixed animation duration. Window-server
    /// commits can be delayed when the test host is contending with another build.
    static func wait(
        timeout: TimeInterval = 2,
        interval: TimeInterval = 0.05,
        until condition: @escaping @MainActor () -> Bool
    ) async throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try await settle(interval)
        }
        return condition()
    }

    static func scrollEvent(deltaY: Double, command: Bool = false) -> NSEvent {
        guard let cgEvent = CGEvent(
            scrollWheelEvent2Source: CGEventSource(stateID: .privateState),
            units: .pixel,
            wheelCount: 1,
            wheel1: Int32(deltaY),
            wheel2: 0,
            wheel3: 0
        ) else { fatalError("could not synthesise a scroll event") }
        if command { cgEvent.flags = .maskCommand }
        guard let event = NSEvent(cgEvent: cgEvent) else {
            fatalError("could not bridge the scroll event")
        }
        return event
    }
}
