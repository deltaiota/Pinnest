//
//  PinController+Hidden.swift
//  Pinnest
//

import AppKit

extension PinController {
    /// Collapses the image panel while retaining its float-exact expanded geometry.
    /// Both frames share their top-centre point, matching a native minimise transform.
    func hide() {
        guard !state.isHidden, !isTransforming else { return }
        isTransforming = true
        if isEditingNumber { endEditingNumber() }
        chrome?.cancelScheduledHide()
        setToolbar(visible: false)
        setHint(nil)

        state.apply(isHidden: true)
        panel.ignoresMouseEvents = false
        panel.hasShadow = true
        let target = hiddenFrame(for: exactFrame)

        isApplyingGeometry = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.transformDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(target, display: true)
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isApplyingGeometry = false
                // Swap content only after the frame reaches 44pt. Animating this
                // conditional replacement keeps the transformed image alive beneath
                // the circle and lets its rotated corners flash past the mask.
                self.state.apply(isHiddenIndicatorVisible: true)
                self.isTransforming = false
                self.scheduleShadowRefresh()
            }
        }
    }

    /// Expands about the same anchor. Piercing resumes only after the transform so
    /// the restoring surface remains reachable without activating Pinnest.
    func restore() {
        guard state.isHidden, !isTransforming else { return }
        isTransforming = true
        state.apply(isHiddenIndicatorVisible: false)
        panel.ignoresMouseEvents = false
        let target = exactFrame

        isApplyingGeometry = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.transformDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(target, display: true)
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isApplyingGeometry = false
                self.isTransforming = false
                self.state.apply(isHidden: false)
                self.panel.ignoresMouseEvents = self.state.isPiercing
                self.updateShadow()
                self.layoutToolbar()
            }
        }
    }

    func hiddenFrame(for expandedFrame: CGRect) -> CGRect {
        PinGeometry.frame(size: Self.hiddenIndicatorSize, anchoredAt: .topCentre, in: expandedFrame)
    }
}
