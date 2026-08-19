//
//  PinController.swift
//  Pinnest
//

import AppKit
import SwiftUI

/// Owns one pin: the image window, its toolbar child window, and the state both render
/// from. Every mutation lands here so the window geometry and the SwiftUI view can
/// never disagree about how big, how transparent, or how rotated a pin is.
@MainActor
final class PinController {
    let state: PinState
    /// Long enough to read as motion, short enough not to feel like waiting.
    private static let resetDuration: TimeInterval = 0.22
    static let hiddenIndicatorSize = CGSize(width: 44, height: 44)
    static let transformDuration: TimeInterval = 0.22

    let panel = PinPanel(
        contentRect: .zero,
        styleMask: [.borderless, .nonactivatingPanel],
        backing: .buffered,
        defer: false
    )
    var chrome: ToolbarPresenter?

    weak var manager: PinManager?
    var shadowRefreshWork: DispatchWorkItem?
    var isEditingNumber = false
    var moveObserver: (any NSObjectProtocol)?
    var isTransforming = false

    /// The authoritative geometry, in exact coordinates.
    ///
    /// `NSWindow.frame` comes back snapped to the backing grid. Feeding that rounded
    /// value into the next zoom step would compound the rounding error, and a
    /// cursor-anchored zoom would visibly crawl off the pointer after a second of
    /// scrolling. So the controller keeps its own float-exact frame and only ever
    /// writes it to the window.
    var exactFrame: CGRect = .zero
    var isApplyingGeometry = false

    var isHidden: Bool {
        state.isHidden
    }

    var isOnActiveSpace: Bool {
        panel.isOnActiveSpace
    }

    init(image: NSImage, centredOn centre: CGPoint, manager: PinManager) {
        let screen = NSScreen.screens.first { $0.frame.contains(centre) } ?? NSScreen.main
        state = PinState(image: image, backingScale: screen?.backingScaleFactor ?? 2)
        self.manager = manager

        configurePanel(centredOn: centre)
        panel.orderFrontRegardless()
        chrome = ToolbarPresenter(
            attachedTo: panel,
            content: PinToolbarView(state: state, controller: self)
        )
        layoutToolbar()

        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.isApplyingGeometry, !self.state.isHidden else { return }
                // Dragging moves the window behind our back, so the exact frame has to
                // pick the new origin back up.
                self.exactFrame.origin = self.panel.frame.origin
                self.layoutToolbar()
            }
        }
    }

    // MARK: Setup

    private func configurePanel(centredOn centre: CGPoint) {
        let screen = NSScreen.screens.first { $0.frame.contains(centre) } ?? NSScreen.main
        let availableFrame = screen?.visibleFrame ?? .zero
        panel.configureAsPinSurface()
        panel.hasShadow = true
        panel.contentView = NSHostingView(rootView: PinImageView(state: state, controller: self))
        exactFrame = PinGeometry.constrain(
            PinGeometry.frame(centeredOn: centre, size: state.displaySize),
            to: availableFrame
        )
        panel.setFrame(exactFrame, display: false)
    }

    // MARK: Interaction

    func handleScroll(_ event: NSEvent) {
        let precise = event.hasPreciseScrollingDeltas
        let raw = precise ? event.scrollingDeltaY : event.deltaY
        let delta = PinGeometry.physicalScrollDelta(
            raw,
            invertedFromDevice: event.isDirectionInvertedFromDevice
        )
        guard delta != 0 else { return }

        if event.modifierFlags.contains(.command) {
            setOpacity(state.opacity + PinGeometry.opacityDelta(scrollDelta: delta, precise: precise))
        } else {
            // Zooming stays under the pointer, so you can scroll your way into a
            // detail instead of chasing the image as it grows past the cursor.
            setScale(
                state.scale * PinGeometry.zoomFactor(scrollDelta: delta, precise: precise),
                anchor: .screenPoint(NSEvent.mouseLocation)
            )
        }
    }

    func setScale(_ scale: CGFloat, anchor: PinGeometry.Anchor = .topCentre) {
        state.apply(scale: PinGeometry.clamp(scale, to: PinGeometry.scaleRange))
        applyGeometry(anchor: anchor)
    }

    func setOpacity(_ opacity: CGFloat) {
        state.apply(opacity: PinGeometry.clamp(opacity, to: PinGeometry.opacityRange))
        updateShadow()
    }

    func rotate(clockwise: Bool = true) {
        let turn = clockwise ? 1 : -1
        state.apply(quarterTurns: ((state.quarterTurns + turn) % 4 + 4) % 4)
        applyGeometry(anchor: .topCentre)
    }

    /// Eases back to a 1:1, unrotated, fully opaque image while keeping the toolbar's
    /// top-centre anchor fixed.
    func reset() {
        let size = PinGeometry.displaySize(base: state.baseSize, scale: 1, quarterTurns: 0)
        let target = PinGeometry.constrain(
            PinGeometry.frame(size: size, anchoredAt: .topCentre, in: exactFrame),
            to: screenFrame
        )
        if state.isHidden {
            exactFrame = target
            state.apply(scale: 1)
            state.apply(quarterTurns: 0)
            state.apply(opacity: 1)
            isApplyingGeometry = true
            panel.setFrame(hiddenFrame(for: target), display: true)
            isApplyingGeometry = false
            updateShadow()
            layoutToolbar()
            return
        }
        exactFrame = target

        // Size is animated by the window; rotation and fade animate in SwiftUI against
        // those live bounds.
        state.apply(scale: 1)
        withAnimation(.easeOut(duration: Self.resetDuration)) {
            state.apply(quarterTurns: 0)
            state.apply(opacity: 1)
        }

        isApplyingGeometry = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.resetDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(target, display: true)
            chrome?.layout(pin: target, screen: screenFrame, animated: true)
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isApplyingGeometry = false
                // Held back until the fade finishes, or the shadow would snap in over
                // a still-translucent image.
                self.updateShadow()
                self.layoutToolbar()
            }
        }
    }

    // MARK: Number editing

    /// Focus is granted only for as long as a number is being typed, then handed
    /// straight back, so the app the user is working in keeps its cursor.
    func beginEditingNumber() {
        isEditingNumber = true
        chrome?.cancelScheduledHide()
        chrome?.setAcceptsKey(true)
    }

    func endEditingNumber() {
        isEditingNumber = false
        chrome?.setAcceptsKey(false)
        if NSApp.isActive { NSApp.deactivate() }
    }

    // MARK: Hover

    /// The union of both windows also covers the gap between them, so travelling from
    /// the image to the toolbar never crosses dead space.
    private var hoverRegion: CGRect {
        guard let chrome else { return exactFrame }
        return exactFrame.union(chrome.frame).insetBy(dx: -6, dy: -6)
    }

    func updateHover(at point: CGPoint) {
        guard !state.isHidden, !isTransforming else {
            chrome?.cancelScheduledHide()
            setToolbar(visible: false)
            return
        }
        if hoverRegion.contains(point) {
            chrome?.cancelScheduledHide()
            setToolbar(visible: true)
        } else if state.isToolbarVisible, !isEditingNumber {
            chrome?.scheduleHide(after: 0.35) { [weak self] in
                MainActor.assumeIsolated { self?.setToolbar(visible: false) }
            }
        }
    }

    func setToolbar(visible: Bool) {
        guard state.isToolbarVisible != visible else { return }
        state.apply(isToolbarVisible: visible)
        if !visible { setHint(nil) }
        chrome?.setVisible(visible)
    }

    // MARK: Hints

    /// Tracks which control the pointer is over. Content is derived at layout time
    /// from current state, so toggles rewrite the hint under the pointer immediately.
    func setHint(_ hint: ToolbarHint?) {
        guard state.hoveredHint != hint else { return }
        state.apply(hoveredHint: hint)
        layoutHint()
    }

    func layoutHint() {
        guard let hint = state.hoveredHint, state.isToolbarVisible else {
            chrome?.hideHint()
            return
        }
        chrome?.showHint(
            hint,
            isPiercing: state.isPiercing,
            isStubborn: state.isStubborn,
            on: screenFrame
        )
    }

    // MARK: Geometry

    var screenFrame: CGRect {
        let centre = CGPoint(x: exactFrame.midX, y: exactFrame.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(centre) } ?? NSScreen.main
        return screen?.visibleFrame ?? .zero
    }

    private func applyGeometry(anchor: PinGeometry.Anchor) {
        var frame = PinGeometry.frame(size: state.displaySize, anchoredAt: anchor, in: exactFrame)
        if case .screenPoint = anchor {
            // Deliberately unclamped. The cursor is inside the frame by construction,
            // so the pin always stays reachable, and shoving it back on screen every
            // step is what would break the anchor and make the image crawl away.
        } else {
            frame = PinGeometry.constrain(frame, to: screenFrame)
        }
        exactFrame = frame

        isApplyingGeometry = true
        panel.setFrame(state.isHidden ? hiddenFrame(for: frame) : frame, display: true)
        isApplyingGeometry = false
        scheduleShadowRefresh()
        layoutToolbar()
    }

    /// A window shadow is derived from the alpha of what the window drew, so a
    /// translucent pin gets a soft box of shadow behind the whole image — exactly the
    /// haze the user is trying to see through. Expanded shadows are opaque-only;
    /// the compact material indicator always keeps its native window shadow.
    func updateShadow() {
        let wantsShadow = state.isHidden || state.opacity >= 1
        if panel.hasShadow != wantsShadow {
            panel.hasShadow = wantsShadow
        }
        scheduleShadowRefresh()
    }

    /// Recomputation samples what the window has *already drawn*, and SwiftUI renders
    /// a rotation on a later pass — so invalidating in the same turn merely recaptures
    /// the old silhouette, which is why a rotated pin kept its previous shadow.
    ///
    /// Debounced rather than merely deferred: a zoom delivers scroll events by the
    /// hundred, and forcing a shadow recompute on each one flickers.
    func scheduleShadowRefresh() {
        shadowRefreshWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.panel.isVisible else { return }
                // A plain invalidate can be ignored when the window's size is
                // unchanged; toggling forces the silhouette to be sampled again.
                if self.panel.hasShadow {
                    self.panel.hasShadow = false
                    self.panel.hasShadow = true
                }
                self.panel.invalidateShadow()
            }
        }
        shadowRefreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    func layoutToolbar() {
        chrome?.layout(pin: exactFrame, screen: screenFrame)
        layoutHint()
    }
}

extension PinController: Equatable, Identifiable {
    nonisolated static func == (lhs: PinController, rhs: PinController) -> Bool {
        lhs === rhs
    }
}
