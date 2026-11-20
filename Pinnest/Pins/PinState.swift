//
//  PinState.swift
//  Pinnest
//

import AppKit
import Observation
import SwiftUI

/// Everything the views render. Mutations go through `PinController` so window
/// geometry and view state can never drift apart.
@MainActor
@Observable
final class PinState {
    let image: NSImage
    let baseSize: CGSize
    let scaleRange: ClosedRange<CGFloat>

    private(set) var scale: CGFloat
    private(set) var opacity: CGFloat = 1
    private(set) var quarterTurns = 0
    private(set) var isPiercing = false
    private(set) var isStubborn = false
    private(set) var isHidden = false
    private(set) var isHiddenIndicatorVisible = false
    private(set) var isToolbarVisible = false
    private(set) var hoveredHint: ToolbarHint?

    init(image: NSImage, backingScale: CGFloat, availableSize: CGSize) {
        self.image = image
        baseSize = PinGeometry.baseSize(pixelSize: Self.pixelSize(of: image), backingScale: backingScale)
        let fit = PinGeometry.openingScale(base: baseSize, available: availableSize)
        scale = fit
        // A panorama may open below 10%. Its first scroll must not snap it back to 10%.
        scaleRange = min(fit, PinGeometry.scaleRange.lowerBound) ... PinGeometry.scaleRange.upperBound
    }

    var displaySize: CGSize {
        PinGeometry.displaySize(base: baseSize, scale: scale, quarterTurns: quarterTurns)
    }

    var rotation: Angle {
        .degrees(Double(quarterTurns) * 90)
    }

    /// `NSImage.size` is in points and lies about Retina captures; the bitmap
    /// representation is the only honest source of pixel dimensions.
    private static func pixelSize(of image: NSImage) -> CGSize {
        let pixels = image.representations.reduce(into: CGSize.zero) { largest, rep in
            let size = CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
            if size.width * size.height > largest.width * largest.height {
                largest = size
            }
        }
        return pixels.width > 0 && pixels.height > 0 ? pixels : image.size
    }
}

/// The setters `PinController` funnels every mutation through. Views read this state
/// but never write it, so window geometry and rendered state cannot drift apart.
extension PinState {
    func apply(scale: CGFloat) {
        self.scale = scale
    }

    func apply(hoveredHint: ToolbarHint?) {
        self.hoveredHint = hoveredHint
    }

    func apply(opacity: CGFloat) {
        self.opacity = opacity
    }

    func apply(quarterTurns: Int) {
        self.quarterTurns = quarterTurns
    }

    func apply(isPiercing: Bool) {
        self.isPiercing = isPiercing
    }

    func apply(isStubborn: Bool) {
        self.isStubborn = isStubborn
    }

    func apply(isHidden: Bool) {
        self.isHidden = isHidden
    }

    func apply(isHiddenIndicatorVisible: Bool) {
        self.isHiddenIndicatorVisible = isHiddenIndicatorVisible
    }

    func apply(isToolbarVisible: Bool) {
        self.isToolbarVisible = isToolbarVisible
    }
}
