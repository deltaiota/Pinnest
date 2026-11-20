//
//  PinGeometry.swift
//  Pinnest
//

import CoreGraphics
import Foundation

/// Pure geometry for pins. Kept free of AppKit so the arithmetic can be tested
/// without a window server.
enum PinGeometry {
    static let scaleRange: ClosedRange<CGFloat> = 0.1 ... 10
    static let opacityRange: ClosedRange<CGFloat> = 0.1 ... 1

    /// Keeps at least this much of a pin on screen, so it can always be grabbed again.
    static let minimumVisibleExtent: CGFloat = 48

    /// The size at which one image pixel covers one device pixel.
    static func baseSize(pixelSize: CGSize, backingScale: CGFloat) -> CGSize {
        let scale = max(backingScale, 1)
        return CGSize(width: pixelSize.width / scale, height: pixelSize.height / scale)
    }

    static func openingScale(base: CGSize, available: CGSize) -> CGFloat {
        guard base.width > 0, base.height > 0, available.width > 0, available.height > 0 else { return 1 }
        return min(1, available.width / base.width, available.height / base.height)
    }

    /// Keep a cascaded opening position if it fits; a screen-sized pin has no room to cascade.
    static func openingFrame(centeredOn centre: CGPoint, size: CGSize, in screen: CGRect) -> CGRect {
        var result = frame(centeredOn: centre, size: size)
        guard !screen.isEmpty else { return result }
        result.origin.x = min(max(result.minX, screen.minX), max(screen.minX, screen.maxX - size.width))
        result.origin.y = min(max(result.minY, screen.minY), max(screen.minY, screen.maxY - size.height))
        return result
    }

    /// Quarter turns swap the bounding box, which is what the window has to resize to.
    static func displaySize(base: CGSize, scale: CGFloat, quarterTurns: Int) -> CGSize {
        let scaled = CGSize(width: base.width * scale, height: base.height * scale)
        return quarterTurns.isMultiple(of: 2)
            ? scaled
            : CGSize(width: scaled.height, height: scaled.width)
    }

    /// Which point of the pin stays put while it resizes.
    enum Anchor {
        /// Zooming under the pointer: the pixel beneath the cursor stays beneath it,
        /// so repeated scrolls walk into the image instead of drifting off it.
        case screenPoint(CGPoint)
        /// Rotating and toolbar-driven resizing: the top edge and horizontal centre
        /// hold still, which is exactly where the toolbar is pinned, so it never jumps.
        case topCentre
        case centre
    }

    /// Zoom is multiplicative so a notch feels the same at any magnification, and the
    /// two delta flavours are normalised: trackpads report points, wheels report lines.
    static func zoomFactor(scrollDelta: CGFloat, precise: Bool) -> CGFloat {
        exp(scrollDelta * (precise ? 0.0025 : 0.05))
    }

    static func opacityDelta(scrollDelta: CGFloat, precise: Bool) -> CGFloat {
        scrollDelta * (precise ? 0.0025 : 0.05)
    }

    /// Turns a scroll delta into physical pointer motion, so pushing your fingers (or
    /// the wheel) *down* always shrinks and fades, whether or not the user runs macOS
    /// with natural scrolling.
    static func physicalScrollDelta(_ delta: CGFloat, invertedFromDevice: Bool) -> CGFloat {
        invertedFromDevice ? -delta : delta
    }

    static func frame(centeredOn centre: CGPoint, size: CGSize) -> CGRect {
        CGRect(
            x: centre.x - size.width / 2,
            y: centre.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    /// Places a resized pin so that `anchor` lands where it already was.
    static func frame(size: CGSize, anchoredAt anchor: Anchor, in old: CGRect) -> CGRect {
        switch anchor {
        case let .screenPoint(point):
            // Momentum can deliver an event after the pointer has left the image.
            // Anchor to the nearest pixel in that case, not to the off-image pointer.
            let ratioX = old.width > 0 ? clamp((point.x - old.minX) / old.width, to: 0 ... 1) : 0.5
            let ratioY = old.height > 0 ? clamp((point.y - old.minY) / old.height, to: 0 ... 1) : 0.5
            return CGRect(
                x: old.minX + ratioX * (old.width - size.width),
                y: old.minY + ratioY * (old.height - size.height),
                width: size.width,
                height: size.height
            )
        case .topCentre:
            return CGRect(
                x: old.midX - size.width / 2,
                y: old.maxY - size.height,
                width: size.width,
                height: size.height
            )
        case .centre:
            return frame(centeredOn: CGPoint(x: old.midX, y: old.midY), size: size)
        }
    }

    /// Nudges a frame back until enough of it overlaps the screen to be reachable.
    static func constrain(_ frame: CGRect, to screen: CGRect) -> CGRect {
        var frame = frame
        let margin = min(minimumVisibleExtent, min(frame.width, frame.height))
        frame.origin.x = min(max(frame.origin.x, screen.minX - frame.width + margin), screen.maxX - margin)
        frame.origin.y = min(max(frame.origin.y, screen.minY - frame.height + margin), screen.maxY - margin)
        return frame
    }

    /// Toolbar sits above the pin, flips below when that would leave the screen, and
    /// tucks inside the pin's top edge when the pin is too tall for either. Whatever
    /// happens, the result is clamped into the visible area — an unreachable toolbar
    /// would strand a pin in piercing mode with no way to turn it off.
    static func toolbarFrame(pin: CGRect, size: CGSize, screen: CGRect, gap: CGFloat = 8) -> CGRect {
        let margin: CGFloat = 4
        let candidates = [
            pin.maxY + gap, // above
            pin.minY - gap - size.height, // below
            pin.maxY - size.height - gap // inside the top edge
        ]
        let fits = candidates.first {
            $0 >= screen.minY + margin && $0 + size.height <= screen.maxY - margin
        }
        let originY = clamp(
            fits ?? candidates[0],
            to: (screen.minY + margin) ... max(screen.minY + margin, screen.maxY - size.height - margin)
        )
        let originX = clamp(
            pin.midX - size.width / 2,
            to: (screen.minX + margin) ... max(screen.minX + margin, screen.maxX - size.width - margin)
        )
        return CGRect(x: originX, y: originY, width: size.width, height: size.height)
    }

    /// The hint bar rides above the toolbar, flipping below it when that would leave
    /// the screen, and clamped horizontally like the toolbar itself.
    static func hintFrame(toolbar: CGRect, size: CGSize, screen: CGRect, gap: CGFloat = 5) -> CGRect {
        let margin: CGFloat = 4
        let above = toolbar.maxY + gap
        let below = toolbar.minY - gap - size.height
        let originY = above + size.height <= screen.maxY - margin ? above : below
        return CGRect(
            x: clamp(
                toolbar.midX - size.width / 2,
                to: (screen.minX + margin) ... max(screen.minX + margin, screen.maxX - size.width - margin)
            ),
            y: clamp(
                originY,
                to: (screen.minY + margin) ... max(screen.minY + margin, screen.maxY - size.height - margin)
            ),
            width: size.width,
            height: size.height
        )
    }

    static func clamp(_ value: CGFloat, to range: ClosedRange<CGFloat>) -> CGFloat {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
