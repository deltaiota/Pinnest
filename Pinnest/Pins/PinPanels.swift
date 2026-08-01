//
//  PinPanels.swift
//  Pinnest
//

import AppKit

/// The image window. It never takes key status, in either mode: a reference image
/// that steals your text cursor is worse than useless.
final class PinPanel: NSPanel {
    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }

    /// AppKit otherwise nudges a window so its top stays clear of the menu bar, which
    /// silently contradicts the geometry the controller just computed. A pin zoomed
    /// under the cursor near the top of a screen would then drift, because the window
    /// ended up somewhere other than where it was put.
    override func constrainFrameRect(_ frameRect: NSRect, to _: NSScreen?) -> NSRect {
        frameRect
    }
}

/// The toolbar window. Key status is opt-in and momentary — clicking a button must not
/// disturb the app underneath, so the panel only becomes focusable while a number is
/// actually being typed.
final class ToolbarPanel: NSPanel {
    var acceptsKey = false

    override var canBecomeKey: Bool {
        acceptsKey
    }

    override var canBecomeMain: Bool {
        false
    }

    /// Placement is clamped into the visible frame deliberately, by `PinGeometry` —
    /// AppKit second-guessing it would only reintroduce drift.
    override func constrainFrameRect(_ frameRect: NSRect, to _: NSScreen?) -> NSRect {
        frameRect
    }
}

extension NSPanel {
    /// Shared configuration for both of a pin's windows: borderless, transparent,
    /// floating above ordinary windows, present on every Space including over
    /// full-screen apps, and invisible to window cycling.
    func configureAsPinSurface() {
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        hasShadow = false
    }
}
