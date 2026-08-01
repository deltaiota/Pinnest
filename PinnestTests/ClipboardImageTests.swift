//
//  ClipboardImageTests.swift
//  PinnestTests
//

import AppKit
@testable import Pinnest
import Testing

@MainActor
struct ClipboardImageTests {
    private func pasteboard(named name: String) -> NSPasteboard {
        let pasteboard = NSPasteboard(name: .init("PinnestTests.\(name)"))
        pasteboard.clearContents()
        return pasteboard
    }

    private func makeImage() -> NSImage {
        let image = NSImage(size: CGSize(width: 40, height: 20))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 40, height: 20).fill()
        image.unlockFocus()
        return image
    }

    @Test func imageOnThePasteboardIsOffered() {
        let pasteboard = pasteboard(named: "image")
        pasteboard.writeObjects([makeImage()])

        #expect(ClipboardImage.isImageAvailable(on: pasteboard))
        #expect(ClipboardImage.read(from: pasteboard) != nil)
    }

    @Test func plainTextIsNotMistakenForAnImage() {
        let pasteboard = pasteboard(named: "text")
        pasteboard.writeObjects(["just some text" as NSString])

        #expect(ClipboardImage.isImageAvailable(on: pasteboard) == false)
        #expect(ClipboardImage.read(from: pasteboard) == nil)
    }

    @Test func anEmptyPasteboardOffersNothing() {
        let pasteboard = pasteboard(named: "empty")

        #expect(ClipboardImage.isImageAvailable(on: pasteboard) == false)
        #expect(ClipboardImage.read(from: pasteboard) == nil)
    }

    /// Copying text after an image must retire the image: only the newest item counts,
    /// which is the rule the menu item's enabled state is built on.
    @Test func onlyTheNewestItemCounts() {
        let pasteboard = pasteboard(named: "sequence")
        pasteboard.writeObjects([makeImage()])
        #expect(ClipboardImage.isImageAvailable(on: pasteboard))

        pasteboard.clearContents()
        pasteboard.writeObjects(["text copied afterwards" as NSString])

        #expect(ClipboardImage.isImageAvailable(on: pasteboard) == false)
    }

    @Test func pinningFromAnImagelessPasteboardCreatesNoPin() {
        let pasteboard = pasteboard(named: "nopin")
        pasteboard.writeObjects(["text" as NSString])
        let manager = PinManager()
        defer { manager.closeAll() }

        manager.pinFromClipboard(from: pasteboard)

        #expect(manager.isEmpty)
    }

    @Test func pinningFromAnImagePasteboardCreatesAPin() {
        let pasteboard = pasteboard(named: "pin")
        pasteboard.writeObjects([makeImage()])
        let manager = PinManager()
        defer { manager.closeAll() }

        manager.pinFromClipboard(from: pasteboard)

        #expect(manager.pins.count == 1)
    }

    @Test func roundTripPreservesTheImage() throws {
        let pasteboard = pasteboard(named: "roundtrip")
        ClipboardImage.write(makeImage(), to: pasteboard)

        let read = try #require(ClipboardImage.read(from: pasteboard))
        #expect(read.size.width / read.size.height == 2)
    }
}
