//
//  PinImageView.swift
//  Pinnest
//

import AppKit
import SwiftUI

struct PinImageView: View {
    let state: PinState
    unowned let controller: PinController

    var body: some View {
        // Sized from the view's own bounds rather than from `state`, so the window is
        // the single source of truth for how big the pin is. Deriving the size from
        // state as well meant two independent interpolations of the same value during
        // an animated resize — SwiftUI's easing against Core Animation's — and the
        // image would slide against its window instead of scaling with it.
        GeometryReader { proxy in
            let box = proxy.size
            let unrotated = state.quarterTurns.isMultiple(of: 2)
                ? box
                : CGSize(width: box.height, height: box.width)

            Image(nsImage: state.image)
                .resizable()
                .interpolation(.high)
                .frame(width: unrotated.width, height: unrotated.height)
                .rotationEffect(state.rotation)
                // Recentres the rotated content inside the window's bounding box.
                .frame(width: box.width, height: box.height)
                .opacity(state.opacity)
        }
        .overlay(ScrollCatcher(controller: controller))
    }
}

/// SwiftUI has no scroll-wheel gesture on macOS, so a bare `NSView` carries the events.
/// It deliberately implements nothing besides scrolling: leaving the rest alone is what
/// lets the pin be dragged and clicked through.
private struct ScrollCatcher: NSViewRepresentable {
    unowned let controller: PinController

    func makeNSView(context _: Context) -> ScrollCatcherView {
        ScrollCatcherView(controller: controller)
    }

    func updateNSView(_ view: ScrollCatcherView, context _: Context) {
        view.controller = controller
    }
}

final class ScrollCatcherView: NSView {
    @MainActor var controller: PinController?

    init(controller: PinController) {
        self.controller = controller
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func scrollWheel(with event: NSEvent) {
        controller?.handleScroll(event)
    }

    /// Dragging the image moves the pin. `performDrag(with:)` runs AppKit's own drag
    /// loop, which beats relying on `isMovableByWindowBackground` — that only works if
    /// nothing in the SwiftUI hierarchy claims the mouse-down first. Combined with
    /// `acceptsFirstMouse`, a pin can be dragged without activating Pinnest.
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
