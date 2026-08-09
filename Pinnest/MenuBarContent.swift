//
//  MenuBarContent.swift
//  Pinnest
//

import Combine
import LaunchAtLogin
import Sparkle
import SwiftUI

struct MenuBarContent: View {
    let pins: PinManager
    let clipboard: ClipboardWatcher
    let updater: SPUUpdater

    private var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var buildVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    var body: some View {
        Section {
            // ⌘V and ⌘W are safe to claim here: a menu-bar extra's shortcuts only
            // fire while its menu is open, so they never compete with Paste or Close
            // Window in the app the user was working in.
            Button("Pin from Clipboard") { pins.pinFromClipboard() }
                .keyboardShortcut("v")
                .disabled(!clipboard.hasImage)

            Button("Close All Pins") { pins.closeAll() }
                .keyboardShortcut("w")
                .disabled(pins.isEmpty)
        }

        Section {
            LaunchAtLogin.Toggle {
                Text("Launch at Login")
            }

            CheckForUpdatesButton(updater: updater)
        }

        Section("Version \(shortVersion) (\(buildVersion))") {
            AboutMenuButton()

            Button("Quit Pinnest") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

private struct CheckForUpdatesButton: View {
    @StateObject private var viewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        _viewModel = StateObject(wrappedValue: CheckForUpdatesViewModel(updater: updater))
    }

    var body: some View {
        Button("Check for Updates…", systemImage: "arrow.trianglehead.2.clockwise.rotate.90") {
            updater.checkForUpdates()
        }
        .disabled(!viewModel.canCheckForUpdates)
    }
}

private final class CheckForUpdatesViewModel: ObservableObject {
    @Published private(set) var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}
