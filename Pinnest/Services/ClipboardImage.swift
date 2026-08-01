//
//  ClipboardImage.swift
//  Pinnest
//

import AppKit
import UniformTypeIdentifiers

/// Reads images from the pasteboard, but only when the *newest* copied item is an
/// image. Asking `NSPasteboard` for an image directly would happily return one
/// carried as a secondary flavour of, say, copied rich text, which is not what the
/// user just copied.
enum ClipboardImage {
    static func isImageAvailable(on pasteboard: NSPasteboard = .general) -> Bool {
        newestImageItem(on: pasteboard) != nil
    }

    static func read(from pasteboard: NSPasteboard = .general) -> NSImage? {
        guard let item = newestImageItem(on: pasteboard) else { return nil }
        for type in item.types where conformsToImage(type) {
            if let data = item.data(forType: type), let image = NSImage(data: data) {
                return image
            }
        }
        return nil
    }

    static func write(_ image: NSImage, to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        pasteboard.writeObjects([image])
    }

    private static func newestImageItem(on pasteboard: NSPasteboard) -> NSPasteboardItem? {
        guard let item = pasteboard.pasteboardItems?.first else { return nil }
        return item.types.contains(where: conformsToImage) ? item : nil
    }

    private nonisolated static func conformsToImage(_ type: NSPasteboard.PasteboardType) -> Bool {
        UTType(type.rawValue)?.conforms(to: .image) ?? false
    }
}
