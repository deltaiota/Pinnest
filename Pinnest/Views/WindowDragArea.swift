//
//  WindowDragArea.swift
//  Pinnest
//

import AppKit
import SwiftUI

/// The toolbar's move handle.
///
/// Deltas are taken from `NSEvent.mouseLocation`, in screen coordinates, rather than
/// from a SwiftUI `DragGesture`. A gesture reports translation in the view's own
/// coordinate space — and that view rides in the window being dragged, so every frame's
/// translation is polluted by the motion it just caused, which reads as lag and jitter.
/// Screen coordinates are the one reference that holds still.
struct WindowDragArea: NSViewRepresentable {
    let onDrag: (CGSize) -> Void

    func makeNSView(context _: Context) -> WindowDragView {
        let view = WindowDragView()
        view.onDrag = onDrag
        return view
    }

    func updateNSView(_ view: WindowDragView, context _: Context) {
        view.onDrag = onDrag
    }
}

final class WindowDragView: NSView {
    var onDrag: ((CGSize) -> Void)?

    private var lastLocation: CGPoint?
    private var trackingArea: NSTrackingArea?

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    /// `.activeAlways` is the part that matters: a pin is never key and Pinnest is
    /// usually not the active app, and without it the cursor would never update.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.cursorUpdate, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func cursorUpdate(with _: NSEvent) {
        currentCursor.set()
    }

    override func mouseEntered(with _: NSEvent) {
        currentCursor.set()
    }

    override func mouseExited(with _: NSEvent) {
        guard lastLocation == nil else { return }
        NSCursor.arrow.set()
    }

    override func mouseDown(with _: NSEvent) {
        lastLocation = NSEvent.mouseLocation
        NSCursor.closedHand.set()
    }

    override func mouseDragged(with _: NSEvent) {
        guard let last = lastLocation else { return }
        let location = NSEvent.mouseLocation
        onDrag?(CGSize(width: location.x - last.x, height: location.y - last.y))
        lastLocation = location
        // AppKit resets the cursor as the pointer moves, so a grabbed hand has to be
        // reasserted for the length of the drag.
        NSCursor.closedHand.set()
    }

    override func mouseUp(with _: NSEvent) {
        lastLocation = nil
        currentCursor.set()
    }

    private var currentCursor: NSCursor {
        lastLocation == nil ? .openHand : .closedHand
    }
}
