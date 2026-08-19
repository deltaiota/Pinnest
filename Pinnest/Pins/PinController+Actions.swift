//
//  PinController+Actions.swift
//  Pinnest
//

import AppKit

extension PinController {
    func togglePiercing() {
        let piercing = !state.isPiercing
        state.apply(isPiercing: piercing)
        panel.ignoresMouseEvents = state.isHidden ? false : piercing
        // The hint text depends on this, and the pointer is still sitting on the
        // button, so refresh it in place rather than waiting for a re-hover.
        layoutHint()
    }

    func toggleStubborn() {
        let stubborn = !state.isStubborn
        let shared = !stubborn
        state.apply(isStubborn: stubborn)

        // `collectionBehavior` alone does not migrate an already ordered all-Spaces
        // window. Re-order the image first so managed mode binds it to the active
        // Desktop, then re-home its toolbar and hint windows onto that same Desktop.
        panel.orderOut(nil)
        panel.applySpacePolicy(shared: shared)
        panel.orderFrontRegardless()
        chrome?.rehome(attachedTo: panel, shared: shared)
        layoutToolbar()
        layoutHint()
    }

    func renderedImage() -> NSImage {
        ImageRotation.rotated(state.image, quarterTurns: state.quarterTurns)
    }

    func copyImage() {
        ClipboardImage.write(renderedImage())
    }

    func move(by delta: CGSize) {
        var frame = exactFrame
        frame.origin.x += delta.width
        frame.origin.y += delta.height

        if state.isHidden {
            exactFrame = frame
            var indicator = hiddenFrame(for: frame)
            let constrained = PinGeometry.constrain(indicator, to: screenFrame)
            exactFrame.origin.x += constrained.minX - indicator.minX
            exactFrame.origin.y += constrained.minY - indicator.minY
            indicator = hiddenFrame(for: exactFrame)

            isApplyingGeometry = true
            panel.setFrameOrigin(indicator.origin)
            isApplyingGeometry = false
        } else {
            exactFrame = PinGeometry.constrain(frame, to: screenFrame)
            isApplyingGeometry = true
            panel.setFrameOrigin(exactFrame.origin)
            isApplyingGeometry = false
            layoutToolbar()
        }
    }

    func close() {
        if let moveObserver { NotificationCenter.default.removeObserver(moveObserver) }
        shadowRefreshWork?.cancel()
        chrome?.close()
        chrome = nil
        panel.orderOut(nil)
        panel.close()
        manager?.remove(self)
    }
}
