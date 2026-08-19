//
//  PinnestApplicationDelegate.swift
//  Pinnest
//

import AppKit

@MainActor
final class PinnestApplicationDelegate: NSObject, NSApplicationDelegate {
    func application(_: NSApplication, open urls: [URL]) {
        PinManager.shared.pinExternalImages(at: urls)
    }

    /// A file-open launch must create pins only. Without this AppKit asks SwiftUI to
    /// open the app's sole Window scene, which is the About window.
    func applicationShouldOpenUntitledFile(_: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        false
    }
}
