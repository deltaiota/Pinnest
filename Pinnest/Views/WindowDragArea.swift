//
//  WindowDragArea.swift
//  Pinnest
//

import AppKit
import SwiftUI

/// Drag surface shared by the image, toolbar grip, and hidden indicator.
///
/// Deltas are taken from `NSEvent.mouseLocation`, in screen coordinates, rather than
/// from a SwiftUI `DragGesture`. A gesture reports translation in the view's own
/// coordinate space — and that view rides in the window being dragged, so every frame's
/// translation is polluted by the motion it just caused, which reads as lag and jitter.
/// Screen coordinates are the one reference that holds still.
struct WindowDragArea: NSViewRepresentable {
    let onDrag: (CGSize) -> Void
    let onClick: (() -> Void)?
    let onHover: ((Bool) -> Void)?
    let onScroll: ((NSEvent) -> Void)?

    init(
        onDrag: @escaping (CGSize) -> Void,
        onClick: (() -> Void)? = nil,
        onHover: ((Bool) -> Void)? = nil,
        onScroll: ((NSEvent) -> Void)? = nil
    ) {
        self.onDrag = onDrag
        self.onClick = onClick
        self.onHover = onHover
        self.onScroll = onScroll
    }

    func makeNSView(context _: Context) -> WindowDragView {
        let view = WindowDragView()
        view.onDrag = onDrag
        view.onClick = onClick
        view.onScroll = onScroll
        view.onHover = onHover
        return view
    }

    func updateNSView(_ view: WindowDragView, context _: Context) {
        view.onDrag = onDrag
        view.onClick = onClick
        view.onHover = onHover
        view.onScroll = onScroll
    }
}

final class WindowDragView: NSView {
    var onDrag: ((CGSize) -> Void)?
    var onClick: (() -> Void)?
    var onHover: ((Bool) -> Void)?
    var onScroll: ((NSEvent) -> Void)?

    private var lastLocation: CGPoint?
    private var didDrag = false
    private var trackingArea: NSTrackingArea?

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    /// `.activeAlways` is the part that matters: a pin is never key and Pinnest is
    /// usually not the active app, and without it the cursor would never update.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
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
        onHover?(true)
    }

    override func mouseExited(with _: NSEvent) {
        guard lastLocation == nil else { return }
        onHover?(false)
        NSCursor.arrow.set()
    }

    override func scrollWheel(with event: NSEvent) {
        if let onScroll {
            onScroll(event)
        } else {
            super.scrollWheel(with: event)
        }
    }

    override func mouseDown(with _: NSEvent) {
        lastLocation = NSEvent.mouseLocation
        didDrag = false
        NSCursor.closedHand.set()
    }

    override func mouseDragged(with _: NSEvent) {
        guard let last = lastLocation else { return }
        let location = NSEvent.mouseLocation
        onDrag?(CGSize(width: location.x - last.x, height: location.y - last.y))
        didDrag = true
        lastLocation = location
        // AppKit resets the cursor as the pointer moves, so a grabbed hand has to be
        // reasserted for the length of the drag.
        NSCursor.closedHand.set()
    }

    override func mouseUp(with event: NSEvent) {
        let shouldClick = !didDrag
        lastLocation = nil
        didDrag = false
        currentCursor.set()
        if !bounds.contains(convert(event.locationInWindow, from: nil)) {
            onHover?(false)
        }
        if shouldClick {
            onClick?()
        }
    }

    private var currentCursor: NSCursor {
        lastLocation == nil ? .openHand : .closedHand
    }
}
