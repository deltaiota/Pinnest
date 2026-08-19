//
//  MenuBarDropTarget.swift
//  Pinnest
//

import AppKit
import SFSafeSymbols
import SwiftUI
import UniformTypeIdentifiers

/// Turns the status item itself into a compact image intake surface.
struct MenuBarDropTarget: View {
    let pins: PinManager

    @State private var isTargeted = false

    var body: some View {
        Image(systemSymbol: .mappinAndEllipse)
            .padding(4)
            .background(isTargeted ? Color.accentColor.opacity(0.24) : .clear, in: Circle())
            .scaleEffect(isTargeted ? 1.12 : 1)
            .animation(.easeOut(duration: 0.12), value: isTargeted)
            .onDrop(
                of: [UTType.fileURL.identifier, UTType.image.identifier],
                isTargeted: $isTargeted,
                perform: accept
            )
            .accessibilityLabel("Pinnest")
    }

    private func accept(_ providers: [NSItemProvider]) -> Bool {
        guard !providers.isEmpty else { return false }
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                loadFileURL(from: provider)
            } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                loadImage(from: provider)
            }
        }
        return true
    }

    private func loadFileURL(from provider: NSItemProvider) {
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL? = if let url = item as? URL {
                url
            } else if let url = item as? NSURL {
                url as URL
            } else if let data = item as? Data {
                URL(dataRepresentation: data, relativeTo: nil)
            } else {
                nil
            }
            guard let url else { return }
            Task { @MainActor in
                pins.pinExternalImages(at: [url])
            }
        }
    }

    /// File representations are valid only for the provider callback. Decode before
    /// hopping to the main actor instead of passing the ephemeral URL onward.
    private func loadImage(from provider: NSItemProvider) {
        provider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, _ in
            guard let url,
                  let data = try? Data(contentsOf: url),
                  let image = NSImage(data: data),
                  image.isValid
            else { return }
            Task { @MainActor in
                pins.pinExternalImage(image)
            }
        }
    }
}
