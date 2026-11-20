//
//  PinToolbarTests.swift
//  PinnestTests
//

import AppKit
@testable import Pinnest
import Testing

/// The toolbar's own behaviour: when it appears, and what the hint bar says.
///
/// Serialized for the same reason as the pin suite — one window server, shared by all.
extension PinWindowSuite {
    @Suite(.serialized)
    @MainActor
    struct Toolbar {
        private func toolbarPanel(near pin: NSWindow) -> NSWindow? {
            NSApp.windows.first { $0 is ToolbarPanel && $0.isVisible }
        }

        /// The 1px hop: toolbar placement used to be derived from the window's rounded
        /// frame, so a pin whose fractional height rounded up and down during a zoom
        /// would shunt the toolbar back and forth.
        ///
        /// The invariant is *no oscillation*, not "never moves": near the top of a
        /// screen the toolbar legitimately flips below the pin, where it then tracks
        /// the growing bottom edge. Jitter is the toolbar reversing direction while
        /// the pin only grows.
        @Test func toolbarDoesNotJitterWhileScaling() throws {
            let manager = PinManager(hoverMonitoring: false)
            defer { manager.closeAll() }
            manager.pin(PinTest.image(width: 337, height: 211))
            let controller = manager.pins[0]
            let pin = try #require(PinTest.panel(of: controller))
            let toolbar = try #require(toolbarPanel(near: pin))
            #expect(toolbar.hasShadow)

            var origins: [CGPoint] = [toolbar.frame.origin]
            for step in 0 ..< 40 {
                controller.setScale(1 + CGFloat(step) * 0.037)
                origins.append(toolbar.frame.origin)
            }

            // The pin grows about a fixed horizontal centre, so x can never move.
            #expect(origins.allSatisfy { $0.x == origins[0].x })

            let steps = zip(origins, origins.dropFirst()).map { $1.y - $0.y }
            #expect(steps.allSatisfy { $0 <= 0 } || steps.allSatisfy { $0 >= 0 })
        }

        @Test func interactingWithAPinAcrossTheMenuBarDoesNotResizeIt() async throws {
            let screen = try #require(NSScreen.main)
            let visible = screen.visibleFrame
            let pointer = CGPoint(x: visible.midX, y: visible.maxY - 30)
            let manager = PinManager(hoverMonitoring: false)
            let controller = PinController(
                image: PinTest.image(width: 180, height: 120),
                centredOn: pointer,
                manager: manager
            )
            defer { controller.close() }
            controller.setScale(3, anchor: .screenPoint(pointer))
            let panel = controller.panel
            let zoomed = panel.frame
            #expect(zoomed.maxY > visible.maxY)

            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                let event = try #require(NSEvent.mouseEvent(
                    with: type, location: panel.convertPoint(fromScreen: pointer), modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: panel.windowNumber,
                    context: nil, eventNumber: 0, clickCount: 1, pressure: 0
                ))
                panel.sendEvent(event)
            }
            controller.move(by: CGSize(width: 8, height: -3))
            await Task.yield()
            #expect(panel.frame == zoomed.offsetBy(dx: 8, dy: -3))
            controller.setScale(3.1, anchor: .screenPoint(pointer))
            #expect(abs(panel.frame.height - zoomed.height * 3.1 / 3) < 1)
        }

        @Test func tallImageOpensFittedButResetsToOneDevicePixelPerImagePixel() async throws {
            let screen = try #require(NSScreen.main)
            let visible = screen.visibleFrame
            let pixels = Int(visible.height * screen.backingScaleFactor * 2)
            // A narrow strip exercises an oversized bitmap without allocating a full-screen texture.
            let bitmap = try #require(NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: 96, pixelsHigh: pixels, bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 32
            ))
            let image = NSImage(size: bitmap.size)
            image.addRepresentation(bitmap)
            let manager = PinManager(hoverMonitoring: false)
            let controller = PinController(
                image: image,
                centredOn: CGPoint(x: visible.midX + 40, y: visible.midY - 40),
                manager: manager
            )
            defer { controller.close() }
            let panel = controller.panel
            #expect(visible.contains(panel.frame))
            #expect(abs(panel.frame.height - visible.height) < 1)
            #expect(controller.state.scale < 1)

            controller.reset()
            let nativeHeight = CGFloat(pixels) / screen.backingScaleFactor
            let restored = try await PinTest.wait { abs(panel.frame.height - nativeHeight) < 1 }
            #expect(restored)
            #expect(controller.state.scale == 1)
        }

        @Test func resetReturnsToTheOriginalGeometry() async throws {
            let manager = PinManager(hoverMonitoring: false)
            defer { manager.closeAll() }
            manager.pin(PinTest.image(width: 300, height: 200))
            let controller = manager.pins[0]
            let pin = try #require(PinTest.panel(of: controller))
            let size = pin.frame.size
            let top = pin.frame.maxY

            controller.setScale(3.4)
            controller.setOpacity(0.4)
            controller.rotate()
            controller.reset()
            let animationSettled = try await PinTest.wait {
                abs(pin.frame.width - size.width) < 1 &&
                    abs(pin.frame.height - size.height) < 1 &&
                    abs(pin.frame.maxY - top) < 1 &&
                    pin.hasShadow
            }
            #expect(animationSettled)

            #expect(controller.state.scale == 1)
            #expect(controller.state.opacity == 1)
            #expect(controller.state.quarterTurns == 0)
            #expect(abs(pin.frame.width - size.width) < 1)
            #expect(abs(pin.frame.height - size.height) < 1)
            #expect(abs(pin.frame.maxY - top) < 1)
            #expect(pin.hasShadow)
        }

        @Test func hintTextFollowsPiercingStateImmediately() {
            let manager = PinManager(hoverMonitoring: false)
            defer { manager.closeAll() }
            manager.pin(PinTest.image(width: 200, height: 100))
            let controller = manager.pins[0]
            func text(_ hint: ToolbarHint, piercing: Bool = false, stubborn: Bool = false) -> String {
                hint.plainText(isPiercing: piercing, isStubborn: stubborn)
            }
            func string(_ resource: LocalizedStringResource) -> String {
                String(localized: resource)
            }

            controller.updateHover(at: CGPoint(x: 0, y: 0))
            controller.setHint(.piercing)

            #expect(text(.piercing) == "\(string("Piercing off")) - \(string("image takes clicks"))")
            #expect(text(.piercing, piercing: true) ==
                "\(string("Piercing on")) - \(string("clicks pass through"))")

            controller.togglePiercing()
            #expect(controller.state.hoveredHint == .piercing)
            #expect(controller.state.isPiercing)

            #expect(text(.stubborn, stubborn: true) ==
                "\(string("Stubborn on")) - \(string("image visible only on this Desktop"))")
            #expect(text(.stubborn) ==
                "\(string("Stubborn off")) - \(string("image visible on every Desktop"))")
            #expect(text(.copy) == "\(string("Copy to clipboard")) / \(string("Drag as image file"))")
            #expect(text(.rotate) ==
                "\(string("Rotate clockwise")) / Shift + \(string("Rotate counterclockwise"))")
            #expect(text(.reset) == string("Reset size, rotation & opacity"))
        }

        @Test func hidingTheToolbarClearsTheHint() async throws {
            let manager = PinManager(hoverMonitoring: false)
            defer { manager.closeAll() }
            manager.pin(PinTest.image(width: 200, height: 100))
            let controller = manager.pins[0]
            let panel = try #require(PinTest.panel(of: controller))

            controller.updateHover(at: CGPoint(x: panel.frame.midX, y: panel.frame.midY))
            controller.setHint(.copy)
            #expect(controller.state.hoveredHint == .copy)

            controller.updateHover(at: CGPoint(x: panel.frame.maxX + 4000, y: panel.frame.midY))
            try await PinTest.settle(0.5)
            #expect(controller.state.isToolbarVisible == false)
            #expect(controller.state.hoveredHint == nil)
        }

        @Test func hoveringOverThePinRevealsItsToolbar() {
            let manager = PinManager(hoverMonitoring: false)
            defer { manager.closeAll() }
            manager.pin(PinTest.image(width: 300, height: 200))
            let controller = manager.pins[0]
            guard let panel = PinTest.panel(of: controller) else {
                Issue.record("pin panel not found")
                return
            }

            #expect(controller.state.isToolbarVisible == false)
            controller.updateHover(at: CGPoint(x: panel.frame.midX, y: panel.frame.midY))
            #expect(controller.state.isToolbarVisible)
        }

        /// Toolbar-driven resizing holds the top edge, because that is where the toolbar
        /// is parked — a centre anchor would slide it under the pointer mid-drag.
        @Test func toolbarResizingHoldsTheTopEdge() throws {
            let manager = PinManager()
            defer { manager.closeAll() }
            manager.pin(PinTest.image(width: 200, height: 100))
            let controller = manager.pins[0]
            let panel = try #require(PinTest.panel(of: controller))
            let top = panel.frame.maxY
            let centreX = panel.frame.midX

            controller.setScale(2)

            #expect(abs(panel.frame.maxY - top) < 1)
            #expect(abs(panel.frame.midX - centreX) < 1)
            #expect(abs(panel.frame.width - controller.state.displaySize.width) < 0.5)
        }
    }
}
