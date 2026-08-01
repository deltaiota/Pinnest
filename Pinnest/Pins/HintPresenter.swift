//
//  HintPresenter.swift
//  Pinnest
//

import AppKit
import SwiftUI

/// Owns the floating hint bar for one pin.
///
/// It lives in its own window so the toolbar never changes size under the pointer, and
/// it never takes mouse events — it must not swallow a click meant for the button it
/// is describing.
@MainActor
final class HintPresenter {
    private let panel = PinPanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )

    init(attachedTo parent: NSWindow) {
        panel.configureAsPinSurface()
        panel.alphaValue = 0
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()
        parent.addChildWindow(panel, ordered: .above)
    }

    /// Rebuilds the label every time: the text is derived from live state, so toggling
    /// a setting rewrites the hint already under the pointer.
    func show(_ text: String, near toolbar: CGRect, on screen: CGRect) {
        let hosting = NSHostingView(rootView: PinHintView(text: text))
        panel.contentView = hosting
        panel.setFrame(
            PinGeometry.hintFrame(toolbar: toolbar, size: hosting.fittingSize, screen: screen),
            display: true
        )
        panel.alphaValue = 1
    }

    func hide() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        }
    }

    func close() {
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
        panel.close()
    }
}
