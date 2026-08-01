//
//  PinGeometryTests.swift
//  PinnestTests
//

import AppKit
@testable import Pinnest
import Testing

struct PinGeometryTests {
    @Test func baseSizeMapsPixelsToDevicePixels() {
        let size = PinGeometry.baseSize(pixelSize: CGSize(width: 800, height: 600), backingScale: 2)
        #expect(size == CGSize(width: 400, height: 300))
    }

    @Test func baseSizeTreatsNonRetinaAsOneToOne() {
        let size = PinGeometry.baseSize(pixelSize: CGSize(width: 800, height: 600), backingScale: 1)
        #expect(size == CGSize(width: 800, height: 600))
    }

    @Test func quarterTurnsSwapTheBoundingBox() {
        let base = CGSize(width: 400, height: 200)
        #expect(PinGeometry.displaySize(base: base, scale: 1, quarterTurns: 0) == CGSize(
            width: 400,
            height: 200
        ))
        #expect(PinGeometry.displaySize(base: base, scale: 1, quarterTurns: 1) == CGSize(
            width: 200,
            height: 400
        ))
        #expect(PinGeometry.displaySize(base: base, scale: 1, quarterTurns: 2) == CGSize(
            width: 400,
            height: 200
        ))
        #expect(PinGeometry.displaySize(base: base, scale: 2, quarterTurns: 3) == CGSize(
            width: 400,
            height: 800
        ))
    }

    /// Zoom must be multiplicative: the same gesture has to feel the same whether the
    /// pin is tiny or huge, and opposite scrolls have to cancel out exactly.
    @Test func zoomIsMultiplicativeAndReversible() {
        let zoomIn = PinGeometry.zoomFactor(scrollDelta: 40, precise: true)
        let zoomOut = PinGeometry.zoomFactor(scrollDelta: -40, precise: true)
        #expect(zoomIn > 1)
        #expect(zoomOut < 1)
        #expect(abs(zoomIn * zoomOut - 1) < 0.0001)
    }

    @Test func coarseWheelStepsBiteHarderThanTrackpadPoints() {
        let wheel = PinGeometry.zoomFactor(scrollDelta: 1, precise: false)
        let trackpad = PinGeometry.zoomFactor(scrollDelta: 1, precise: true)
        #expect(wheel > trackpad)
    }

    @Test func clampHoldsTheDocumentedLimits() {
        #expect(PinGeometry.clamp(0, to: PinGeometry.opacityRange) == 0.1)
        #expect(PinGeometry.clamp(5, to: PinGeometry.opacityRange) == 1)
        #expect(PinGeometry.clamp(0.001, to: PinGeometry.scaleRange) == 0.1)
        #expect(PinGeometry.clamp(99, to: PinGeometry.scaleRange) == 10)
    }

    @Test func toolbarSitsAboveThePinWhenThereIsRoom() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let pin = CGRect(x: 400, y: 300, width: 200, height: 100)
        let toolbar = PinGeometry.toolbarFrame(pin: pin, size: CGSize(width: 240, height: 30), screen: screen)
        #expect(toolbar.minY == pin.maxY + 8)
        #expect(abs(toolbar.midX - pin.midX) < 0.001)
    }

    @Test func toolbarFlipsBelowWhenItWouldLeaveTheScreen() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let pin = CGRect(x: 400, y: 700, width: 200, height: 90)
        let toolbar = PinGeometry.toolbarFrame(pin: pin, size: CGSize(width: 240, height: 30), screen: screen)
        #expect(toolbar.maxY == pin.minY - 8)
    }

    @Test func toolbarStaysOnScreenForPinsAtTheEdge() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let pin = CGRect(x: 970, y: 300, width: 20, height: 20)
        let toolbar = PinGeometry.toolbarFrame(pin: pin, size: CGSize(width: 240, height: 30), screen: screen)
        #expect(toolbar.maxX <= screen.maxX)
        #expect(toolbar.minX >= screen.minX)
    }

    /// A pin taller than the screen leaves no room above or below, and a toolbar you
    /// cannot reach means a piercing pin you cannot switch off.
    @Test func toolbarTucksInsideAPinTallerThanTheScreen() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let pin = CGRect(x: 100, y: -400, width: 600, height: 1600)
        let toolbar = PinGeometry.toolbarFrame(pin: pin, size: CGSize(width: 240, height: 30), screen: screen)
        #expect(toolbar.minY >= screen.minY)
        #expect(toolbar.maxY <= screen.maxY)
        #expect(screen.contains(toolbar))
    }

    @Test func scrollDirectionFollowsThePhysicalGesture() {
        // Natural scrolling on: fingers down reports a positive delta.
        #expect(PinGeometry.physicalScrollDelta(12, invertedFromDevice: true) == -12)
        // Natural scrolling off: a wheel pushed down reports a negative delta.
        #expect(PinGeometry.physicalScrollDelta(-12, invertedFromDevice: false) == -12)

        // Either way, pushing down has to shrink and fade.
        let naturalDown = PinGeometry.physicalScrollDelta(12, invertedFromDevice: true)
        let classicDown = PinGeometry.physicalScrollDelta(-12, invertedFromDevice: false)
        #expect(PinGeometry.zoomFactor(scrollDelta: naturalDown, precise: true) < 1)
        #expect(PinGeometry.zoomFactor(scrollDelta: classicDown, precise: false) < 1)
        #expect(PinGeometry.opacityDelta(scrollDelta: naturalDown, precise: true) < 0)
        #expect(PinGeometry.opacityDelta(scrollDelta: classicDown, precise: false) < 0)
    }

    @Test func topCentreAnchorHoldsTheTopEdge() {
        let old = CGRect(x: 100, y: 100, width: 200, height: 100)
        let new = PinGeometry.frame(size: CGSize(width: 400, height: 200), anchoredAt: .topCentre, in: old)
        #expect(new.maxY == old.maxY)
        #expect(new.midX == old.midX)
    }

    @Test func screenPointAnchorKeepsThatPointOverTheSameSpotOfTheImage() {
        let old = CGRect(x: 100, y: 100, width: 200, height: 100)
        let cursor = CGPoint(x: 150, y: 125) // a quarter in, a quarter up
        let new = PinGeometry.frame(
            size: CGSize(width: 600, height: 300),
            anchoredAt: .screenPoint(cursor),
            in: old
        )

        #expect(abs((cursor.x - new.minX) / new.width - (cursor.x - old.minX) / old.width) < 0.0001)
        #expect(abs((cursor.y - new.minY) / new.height - (cursor.y - old.minY) / old.height) < 0.0001)
    }

    /// Scrolling with the cursor outside the pin must not fling it away.
    @Test func screenPointAnchorClampsACursorOutsideThePin() {
        let old = CGRect(x: 100, y: 100, width: 200, height: 100)
        let cursor = CGPoint(x: 5000, y: 5000)
        let new = PinGeometry.frame(
            size: CGSize(width: 400, height: 200),
            anchoredAt: .screenPoint(cursor),
            in: old
        )
        #expect(new.maxX == cursor.x)
        #expect(new.maxY == cursor.y)
    }

    @Test func scaleReachesOneThousandPercent() {
        #expect(PinGeometry.scaleRange.upperBound == 10)
        #expect(PinGeometry.clamp(50, to: PinGeometry.scaleRange) == 10)
    }

    /// A pin dragged far off screen has to keep a grabbable sliver on it.
    @Test func constrainKeepsAGrabbableSliverOnScreen() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let runaway = CGRect(x: 5000, y: -4000, width: 300, height: 200)
        let constrained = PinGeometry.constrain(runaway, to: screen)
        #expect(constrained.intersects(screen))
        #expect(constrained.intersection(screen).width >= PinGeometry.minimumVisibleExtent - 0.001)
        #expect(constrained.intersection(screen).height >= PinGeometry.minimumVisibleExtent - 0.001)
    }

    @Test func constrainLeavesAnOnScreenPinAlone() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let frame = CGRect(x: 100, y: 100, width: 300, height: 200)
        #expect(PinGeometry.constrain(frame, to: screen) == frame)
    }
}
