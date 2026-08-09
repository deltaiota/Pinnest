//
//  CopyDragAreaTests.swift
//  PinnestTests
//

import AppKit
@testable import Pinnest
import Testing

@MainActor
struct CopyDragAreaTests {
    @Test func mouseUpWithoutADragPerformsOneCopy() throws {
        let view = CopyDragView(frame: CGRect(x: 0, y: 0, width: 58, height: 20))
        var copyCount = 0
        view.onClick = { copyCount += 1 }

        let down = try #require(mouseEvent(type: .leftMouseDown))
        let mouseUp = try #require(mouseEvent(type: .leftMouseUp))
        view.mouseDown(with: down)
        view.mouseUp(with: mouseUp)

        #expect(copyCount == 1)
    }

    private func mouseEvent(type: NSEvent.EventType) -> NSEvent? {
        NSEvent.mouseEvent(
            with: type,
            location: CGPoint(x: 10, y: 10),
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: type == .leftMouseDown ? 1 : 0
        )
    }
}
