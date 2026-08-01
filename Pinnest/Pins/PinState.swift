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

    private(set) var scale: CGFloat = 1
    private(set) var opacity: CGFloat = 1
    private(set) var quarterTurns = 0
    private(set) var isPiercing = false
    private(set) var isToolbarVisible = false
    private(set) var hoveredHint: ToolbarHint?

    init(image: NSImage, backingScale: CGFloat) {
        self.image = image
        baseSize = PinGeometry.baseSize(pixelSize: Self.pixelSize(of: image), backingScale: backingScale)
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

    func apply(isToolbarVisible: Bool) {
        self.isToolbarVisible = isToolbarVisible
    }
}
