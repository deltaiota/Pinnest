//
//  MenuBarContent.swift
//  Pinnest
//

import LaunchAtLogin
import SwiftUI

struct MenuBarContent: View {
    let pins: PinManager
    let clipboard: ClipboardWatcher

    var body: some View {
        // ⌘V and ⌘W are safe to claim here: a menu bar extra's shortcuts only fire
        // while its menu is open, so they never compete with Paste or Close Window in
        // the app you were using.
        Button("Pin from Clipboard") { pins.pinFromClipboard() }
            .keyboardShortcut("v")
            .disabled(!clipboard.hasImage)

        Button("Close All Pins") { pins.closeAll() }
            .keyboardShortcut("w")
            .disabled(pins.isEmpty)

        Divider()

        LaunchAtLogin.Toggle("Launch at Login")

        Divider()

        Button("Quit Pinnest") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
