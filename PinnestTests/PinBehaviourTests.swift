//
//  PinBehaviourTests.swift
//  PinnestTests
//

import AppKit
@testable import Pinnest
import Testing

/// These drive the real windows inside the host app, so they exercise what the plan's
/// spike proved by hand: hit-test routing, piercing, geometry, and focus policy.
///
/// Serialized on purpose: these tests share one window server, and pins from
/// concurrently running tests would overlap each other's hit tests.
extension PinWindowSuite {
    @Suite(.serialized)
    @MainActor
    struct Behaviour {
        // MARK: Tests

        @Test func pinningPresentsAFloatingPanelOnEverySpace() throws {
            let manager = PinManager()
            defer { manager.closeAll() }

            manager.pin(PinTest.image(width: 200, height: 100))

            #expect(manager.pins.count == 1)
            let panel = try #require(PinTest.panel(of: manager.pins[0]))
            #expect(panel.level == .floating)
            #expect(panel.collectionBehavior.contains(.canJoinAllSpaces))
            #expect(panel.collectionBehavior.contains(.fullScreenAuxiliary))
        }

        @Test func stubbornDefaultsOffAndTogglesAllWindowsTogether() throws {
            let manager = PinManager(hoverMonitoring: false)
            defer { manager.closeAll() }
            manager.pin(PinTest.image(width: 200, height: 100))
            let controller = manager.pins[0]
            let panel = try #require(PinTest.panel(of: controller))

            #expect(controller.state.isStubborn == false)
            #expect(panel.collectionBehavior.contains(.canJoinAllSpaces))

            controller.toggleStubborn()
            #expect(panel.isOnActiveSpace)

            #expect(controller.state.isStubborn)
            let localWindows = [panel] + (panel.childWindows ?? [])
            #expect(localWindows.count == 3)
            #expect(localWindows.allSatisfy { $0.collectionBehavior.contains(.managed) })
            #expect(localWindows.allSatisfy { !$0.collectionBehavior.contains(.canJoinAllSpaces) })
            #expect(!localWindows.contains { !$0.isOnActiveSpace })

            controller.toggleStubborn()

            #expect(controller.state.isStubborn == false)
            #expect(localWindows.allSatisfy { $0.collectionBehavior.contains(.canJoinAllSpaces) })
            #expect(localWindows.allSatisfy { $0.collectionBehavior.contains(.fullScreenAuxiliary) })
        }

        /// The pin must never take keyboard focus, which is the whole point of a reference
        /// image that floats over the app you are actually working in.
        @Test func pinPanelRefusesKeyStatus() {
            let manager = PinManager()
            defer { manager.closeAll() }
            manager.pin(PinTest.image(width: 200, height: 100))

            let panel = PinTest.panel(of: manager.pins[0])
            panel?.makeKey()
            #expect(panel?.canBecomeKey == false)
            #expect(panel?.isKeyWindow == false)
        }

        @Test func piercingMakesThePinTransparentToClicks() async throws {
            let manager = PinManager()
            defer { manager.closeAll() }
            manager.pin(PinTest.image(width: 300, height: 200))
            let controller = manager.pins[0]
            let panel = try #require(PinTest.panel(of: controller))
            // The window server needs a turn to composite a new window before it will
            // report it in a hit test.
            try await PinTest.settle()
            let centre = CGPoint(x: panel.frame.midX, y: panel.frame.midY)

            #expect(PinTest.hitWindow(at: centre) == panel.windowNumber)

            controller.togglePiercing()
            try await PinTest.settle()
            #expect(controller.state.isPiercing)
            #expect(PinTest.hitWindow(at: centre) != panel.windowNumber)

            controller.togglePiercing()
            try await PinTest.settle()
            #expect(PinTest.hitWindow(at: centre) == panel.windowNumber)
        }

        @Test func scrollingScalesAndCommandScrollingFadesThePin() {
            let manager = PinManager()
            defer { manager.closeAll() }
            manager.pin(PinTest.image(width: 200, height: 100))
            let controller = manager.pins[0]

            controller.handleScroll(PinTest.scrollEvent(deltaY: 40))
            #expect(controller.state.scale > 1)
            #expect(controller.state.opacity == 1)

            let scaled = controller.state.scale
            controller.handleScroll(PinTest.scrollEvent(deltaY: -40, command: true))
            #expect(controller.state.opacity < 1)
            #expect(controller.state.scale == scaled)
        }

        @Test func opacityStopsAtTenPercentAndScaleAtItsLimits() {
            let manager = PinManager()
            defer { manager.closeAll() }
            manager.pin(PinTest.image(width: 200, height: 100))
            let controller = manager.pins[0]

            for _ in 0 ..< 40 {
                controller.handleScroll(PinTest.scrollEvent(deltaY: -100, command: true))
            }
            #expect(controller.state.opacity == 0.1)

            for _ in 0 ..< 60 {
                controller.handleScroll(PinTest.scrollEvent(deltaY: -100))
            }
            #expect(controller.state.scale == PinGeometry.scaleRange.lowerBound)

            for _ in 0 ..< 200 {
                controller.handleScroll(PinTest.scrollEvent(deltaY: 100))
            }
            #expect(controller.state.scale == PinGeometry.scaleRange.upperBound)
        }

        /// Scroll zoom keeps the pixel under the cursor under the cursor, so repeated
        /// scrolls walk into a detail instead of pushing it away.
        @Test func scrollZoomHoldsThePointUnderTheCursor() throws {
            let manager = PinManager()
            defer { manager.closeAll() }
            manager.pin(PinTest.image(width: 400, height: 300))
            let controller = manager.pins[0]
            let panel = try #require(PinTest.panel(of: controller))

            let old = panel.frame
            // A point a quarter of the way in from the top left of the pin.
            let cursor = CGPoint(x: old.minX + old.width / 4, y: old.minY + old.height / 4)
            let ratioBefore = CGPoint(
                x: (cursor.x - old.minX) / old.width,
                y: (cursor.y - old.minY) / old.height
            )

            controller.setScale(2, anchor: .screenPoint(cursor))

            let new = panel.frame
            let ratioAfter = CGPoint(
                x: (cursor.x - new.minX) / new.width,
                y: (cursor.y - new.minY) / new.height
            )
            #expect(abs(ratioAfter.x - ratioBefore.x) < 0.01)
            #expect(abs(ratioAfter.y - ratioBefore.y) < 0.01)
        }

        /// The regression that mattered: a burst of small zoom steps at a fixed cursor.
        /// Reading the rounded `NSWindow.frame` back as the input to the next step made
        /// the error compound until the image crawled out from under the pointer.
        @Test func repeatedZoomStepsDoNotDriftAwayFromTheCursor() throws {
            let manager = PinManager()
            defer { manager.closeAll() }
            manager.pin(PinTest.image(width: 400, height: 300))
            let controller = manager.pins[0]
            let panel = try #require(PinTest.panel(of: controller))

            let start = panel.frame
            let cursor = CGPoint(x: start.minX + start.width * 0.3, y: start.minY + start.height * 0.7)
            let ratio = CGPoint(
                x: (cursor.x - start.minX) / start.width,
                y: (cursor.y - start.minY) / start.height
            )

            // 60 zoom-ins then 60 zoom-outs, the way a trackpad delivers a scroll burst.
            for _ in 0 ..< 60 {
                controller.setScale(controller.state.scale * 1.03, anchor: .screenPoint(cursor))
            }
            for _ in 0 ..< 60 {
                controller.setScale(controller.state.scale / 1.03, anchor: .screenPoint(cursor))
            }

            let end = panel.frame
            let endRatio = CGPoint(
                x: (cursor.x - end.minX) / end.width,
                y: (cursor.y - end.minY) / end.height
            )
            #expect(abs(endRatio.x - ratio.x) < 0.01)
            #expect(abs(endRatio.y - ratio.y) < 0.01)
            // Round-tripping the zoom must land back on the original geometry.
            #expect(abs(end.width - start.width) < 1)
            #expect(abs(end.minX - start.minX) < 1)
            #expect(abs(end.minY - start.minY) < 1)
        }

        @Test func rotatingSwapsTheWindowsDimensionsAndHoldsTheTopEdge() throws {
            let manager = PinManager()
            defer { manager.closeAll() }
            manager.pin(PinTest.image(width: 400, height: 200))
            let controller = manager.pins[0]
            let panel = try #require(PinTest.panel(of: controller))
            let before = panel.frame

            controller.rotate()

            #expect(controller.state.quarterTurns == 1)
            #expect(abs(panel.frame.width - before.height) < 0.5)
            #expect(abs(panel.frame.height - before.width) < 0.5)
            // The toolbar is anchored to the pin's top edge, so it must not have moved.
            #expect(abs(panel.frame.maxY - before.maxY) < 1)
            #expect(abs(panel.frame.midX - before.midX) < 1)
        }

        /// Rotation changes the drawn silhouette, so the pin's shadow has to keep
        /// agreeing with its opacity rather than lingering from the previous shape.
        @Test func rotationKeepsTheShadowConsistentWithOpacity() throws {
            let manager = PinManager()
            defer { manager.closeAll() }
            manager.pin(PinTest.image(width: 400, height: 200))
            let controller = manager.pins[0]
            let panel = try #require(PinTest.panel(of: controller))

            controller.rotate()
            #expect(panel.hasShadow)

            controller.setOpacity(0.5)
            controller.rotate()
            #expect(panel.hasShadow == false)

            controller.setOpacity(1)
            controller.rotate()
            #expect(panel.hasShadow)
        }

        @Test func shiftRotatesTheOtherWay() {
            let manager = PinManager()
            defer { manager.closeAll() }
            manager.pin(PinTest.image(width: 400, height: 200))
            let controller = manager.pins[0]

            controller.rotate(clockwise: false)
            #expect(controller.state.quarterTurns == 3)

            controller.rotate(clockwise: true)
            #expect(controller.state.quarterTurns == 0)
        }

        /// A translucent pin must not drag a window shadow around behind it — that haze is
        /// exactly what you are trying to see through.
        @Test func shadowIsDroppedWhileThePinIsTranslucent() throws {
            let manager = PinManager()
            defer { manager.closeAll() }
            manager.pin(PinTest.image(width: 300, height: 200))
            let controller = manager.pins[0]
            let panel = try #require(PinTest.panel(of: controller))

            #expect(panel.hasShadow)

            controller.setOpacity(0.5)
            #expect(panel.hasShadow == false)

            controller.setOpacity(1)
            #expect(panel.hasShadow)
        }

        /// `NSImage` sizes are in points and depend on the backing scale of whatever
        /// display drew them, so the contract worth asserting is that the aspect ratio
        /// inverted — a landscape image came back portrait.
        @Test func copyingPutsTheRotatedImageOnThePasteboard() throws {
            let pasteboard = NSPasteboard(name: .init("PinnestTestPasteboard"))
            let manager = PinManager()
            defer { manager.closeAll() }
            manager.pin(PinTest.image(width: 400, height: 200))
            let controller = manager.pins[0]
            controller.rotate()

            let source = controller.state.image
            ClipboardImage.write(ImageRotation.rotated(source, quarterTurns: 1), to: pasteboard)

            let copied = try #require(ClipboardImage.read(from: pasteboard))
            #expect(source.size.width > source.size.height)
            #expect(copied.size.height > copied.size.width)
            #expect(abs(copied.size.height / copied.size.width - source.size.width / source.size.height) <
                0.01)
        }

        @Test func closingRemovesThePinAndItsWindows() {
            let manager = PinManager()
            manager.pin(PinTest.image(width: 200, height: 100))
            let controller = manager.pins[0]
            let panel = PinTest.panel(of: controller)

            controller.close()

            #expect(manager.pins.isEmpty)
            #expect(panel?.isVisible == false)
        }

        @Test func pinsAreIndependent() {
            let manager = PinManager()
            defer { manager.closeAll() }
            manager.pin(PinTest.image(width: 200, height: 100))
            manager.pin(PinTest.image(width: 200, height: 100))

            manager.pins[0].setScale(3)
            manager.pins[1].togglePiercing()

            #expect(manager.pins[0].state.scale == 3)
            #expect(manager.pins[1].state.scale == 1)
            #expect(manager.pins[0].state.isPiercing == false)
            #expect(manager.pins[1].state.isPiercing)
        }
    }
}
