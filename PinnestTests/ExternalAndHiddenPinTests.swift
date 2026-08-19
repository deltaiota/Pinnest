//
//  ExternalAndHiddenPinTests.swift
//  PinnestTests
//

import AppKit
@testable import Pinnest
import Testing

extension PinWindowSuite {
    @Suite(.serialized)
    @MainActor
    struct ExternalAndHidden {
        @Test func externalImageFilesCreateIndependentPins() throws {
            let manager = PinManager(hoverMonitoring: false)
            defer { manager.closeAll() }

            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }

            let first = directory.appendingPathComponent("first.tiff")
            let second = directory.appendingPathComponent("second.tiff")
            try #require(PinTest.image(width: 120, height: 80).tiffRepresentation).write(to: first)
            try #require(PinTest.image(width: 90, height: 60).tiffRepresentation).write(to: second)

            manager.pinExternalImages(at: [first, second])

            #expect(manager.pins.count == 2)
            #expect(manager.pins[0] !== manager.pins[1])
        }

        @Test func hiddenIndicatorRestoresExpandedFrameAndPiercing() async throws {
            let manager = PinManager(hoverMonitoring: false)
            defer { manager.closeAll() }
            manager.pin(PinTest.image(width: 300, height: 200))
            let controller = manager.pins[0]
            let panel = try #require(PinTest.panel(of: controller))
            let expandedFrame = panel.frame

            controller.togglePiercing()
            controller.hide()

            let hidden = try await PinTest.wait {
                controller.isHidden &&
                    controller.state.isHiddenIndicatorVisible &&
                    abs(panel.frame.width - 44) < 1 &&
                    abs(panel.frame.height - 44) < 1
            }
            #expect(hidden)
            #expect(panel.ignoresMouseEvents == false)
            #expect(panel.hasShadow)

            controller.restore()

            let restored = try await PinTest.wait {
                !controller.isHidden &&
                    abs(panel.frame.minX - expandedFrame.minX) < 1 &&
                    abs(panel.frame.minY - expandedFrame.minY) < 1 &&
                    abs(panel.frame.width - expandedFrame.width) < 1 &&
                    abs(panel.frame.height - expandedFrame.height) < 1
            }
            #expect(restored)
            #expect(controller.state.isPiercing)
            #expect(panel.ignoresMouseEvents)
        }

        @Test func scopedCloseCountsAllSpacesPinsAsCurrentAndCanPreserveHiddenPins() throws {
            let manager = PinManager(hoverMonitoring: false)
            defer { manager.closeAll() }
            manager.pin(PinTest.image(width: 200, height: 100))
            manager.pin(PinTest.image(width: 200, height: 100))
            let hidden = try #require(manager.pins.last)
            hidden.hide()

            #expect(manager.pinCount(in: .currentDesktop) == 2)
            #expect(manager.pinCount(in: .otherDesktops) == 0)
            #expect(manager.pinCount(in: .all) == 2)
            #expect(manager.pinCount(in: .currentDesktop, excludingHidden: true) == 1)
            #expect(manager.pinCount(in: .all, excludingHidden: true) == 1)
            #expect(manager.hiddenPinCount == 1)

            manager.closePins(in: .currentDesktop, excludingHidden: true)

            #expect(manager.pins.count == 1)
            #expect(manager.pins[0] === hidden)
            #expect(hidden.isHidden)

            manager.closeHiddenPins()
            #expect(manager.isEmpty)
        }

        @Test func globalCloseIncludesHiddenPinsByDefault() throws {
            let manager = PinManager(hoverMonitoring: false)
            defer { manager.closeAll() }
            manager.pin(PinTest.image(width: 200, height: 100))
            manager.pin(PinTest.image(width: 200, height: 100))
            let hidden = try #require(manager.pins.last)
            hidden.hide()

            manager.closePins(in: .all)

            #expect(manager.isEmpty)
        }
    }
}
