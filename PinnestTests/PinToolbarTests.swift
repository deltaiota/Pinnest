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
            controller.reset()
            // The animation has to land before the geometry is final.
            try await PinTest.settle(0.5)

            #expect(controller.state.scale == 1)
            #expect(controller.state.opacity == 1)
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

            controller.updateHover(at: CGPoint(x: 0, y: 0))
            controller.setHint(.piercing)

            #expect(ToolbarHint.piercing.text(isPiercing: false).contains("off"))
            #expect(ToolbarHint.piercing.text(isPiercing: true).contains("on"))

            controller.togglePiercing()
            #expect(controller.state.hoveredHint == .piercing)
            #expect(controller.state.isPiercing)
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
