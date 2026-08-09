//
//  ToolbarPresenter.swift
//  Pinnest
//

import AppKit
import SwiftUI

/// Owns a pin's chrome: the toolbar window, whether it is showing, and the hint bar
/// that rides above it. Keeping this out of `PinController` leaves that type to do one
/// job — track the pin's geometry.
@MainActor
final class ToolbarPresenter {
    private let panel = ToolbarPanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    private let hint: HintPresenter
    private let size: CGSize
    private var hideWork: DispatchWorkItem?

    private(set) var isVisible = false

    init(attachedTo parent: NSWindow, content: some View) {
        panel.configureAsPinSurface()
        let hosting = NSHostingView(rootView: content)
        panel.contentView = hosting
        // Measured once: a toolbar that resized as its contents changed would jitter
        // under the pointer.
        size = hosting.fittingSize
        panel.setContentSize(size)
        panel.hasShadow = true
        panel.invalidateShadow()
        panel.alphaValue = 0
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()
        parent.addChildWindow(panel, ordered: .above)
        hint = HintPresenter(attachedTo: parent)
    }

    var frame: CGRect {
        panel.frame
    }

    /// Placement derives from the pin's *exact* frame, then snaps to whole points:
    /// reading the window's own rounded frame made the toolbar hop by a pixel as the
    /// pin's fractional height rounded up and down during a zoom.
    func layout(pin: CGRect, screen: CGRect) {
        var frame = PinGeometry.toolbarFrame(pin: pin, size: size, screen: screen)
        frame.origin.x = frame.origin.x.rounded()
        frame.origin.y = frame.origin.y.rounded()
        panel.setFrame(frame, display: true)
    }

    func layout(pin: CGRect, screen: CGRect, animated: Bool) {
        guard animated else { return layout(pin: pin, screen: screen) }
        var frame = PinGeometry.toolbarFrame(pin: pin, size: size, screen: screen)
        frame.origin.x = frame.origin.x.rounded()
        frame.origin.y = frame.origin.y.rounded()
        panel.animator().setFrame(frame, display: true)
    }

    func setVisible(_ visible: Bool) {
        guard isVisible != visible else { return }
        isVisible = visible
        hideWork?.cancel()
        panel.ignoresMouseEvents = !visible
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = visible ? 1 : 0
        }
    }

    /// Hiding is delayed so that travelling from the image to the toolbar, or pausing
    /// between controls, does not flicker it away.
    func scheduleHide(after delay: TimeInterval, then handler: @escaping () -> Void) {
        hideWork?.cancel()
        let work = DispatchWorkItem { handler() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func cancelScheduledHide() {
        hideWork?.cancel()
    }

    func showHint(_ hintValue: ToolbarHint, isPiercing: Bool, isStubborn: Bool, on screen: CGRect) {
        hint.show(
            hintValue,
            isPiercing: isPiercing,
            isStubborn: isStubborn,
            near: panel.frame,
            on: screen
        )
    }

    func hideHint() {
        hint.hide()
    }

    /// Key status is momentary, granted only while a number is being typed.
    func setAcceptsKey(_ accepts: Bool) {
        panel.acceptsKey = accepts
        if accepts { panel.makeKey() }
    }

    /// Collection behavior does not migrate a window that is already ordered on all
    /// Spaces. Detach and re-order both chrome windows so `managed` really binds them
    /// to the active Space rather than merely changing their flags.
    func rehome(attachedTo parent: NSWindow, shared: Bool) {
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
        panel.applySpacePolicy(shared: shared)
        panel.orderFrontRegardless()
        parent.addChildWindow(panel, ordered: .above)
        hint.rehome(attachedTo: parent, shared: shared)
    }

    func close() {
        hideWork?.cancel()
        hint.close()
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
        panel.close()
    }
}
