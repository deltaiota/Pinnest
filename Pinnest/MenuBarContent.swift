//
//  MenuBarContent.swift
//  Pinnest
//

import AppKit
import Combine
import LaunchAtLogin
import Sparkle
import SwiftUI
import UniformTypeIdentifiers

struct MenuBarContent: View {
    let pins: PinManager
    let clipboard: ClipboardWatcher
    let updater: SPUUpdater

    @State private var isOptionHeld = false
    @State private var optionWatcher: Timer?

    private var currentDesktopCloseLabel: LocalizedStringKey {
        isOptionHeld ? "Close Visible Pins on This Desktop" : "Close Pins on This Desktop"
    }

    private var otherDesktopsCloseLabel: LocalizedStringKey {
        isOptionHeld ? "Close Visible Pins on Other Desktops" : "Close Pins on Other Desktops"
    }

    private var allDesktopsCloseLabel: LocalizedStringKey {
        isOptionHeld ? "Close All Visible Pins" : "Close All Pins"
    }

    private var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var buildVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    var body: some View {
        Group {
            Section {
                // ⌘V and ⌘W are safe to claim here: a menu-bar extra's shortcuts only
                // fire while its menu is open, so they never compete with Paste or Close
                // Window in the app the user was working in.
                Button("Pin from Clipboard") { pins.pinFromClipboard() }
                    .keyboardShortcut("v")
                    .disabled(!clipboard.hasImage)

                Button("Pin from File…", action: chooseImageFiles)

                Divider()

                Button(currentDesktopCloseLabel) {
                    pins.closePins(in: .currentDesktop, excludingHidden: isOptionHeld)
                }
                .keyboardShortcut("w")
                .disabled(pins.pinCount(in: .currentDesktop, excludingHidden: isOptionHeld) == 0)

                Button(otherDesktopsCloseLabel) {
                    pins.closePins(in: .otherDesktops, excludingHidden: isOptionHeld)
                }
                .disabled(pins.pinCount(in: .otherDesktops, excludingHidden: isOptionHeld) == 0)

                Button(allDesktopsCloseLabel) {
                    pins.closePins(in: .all, excludingHidden: isOptionHeld)
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
                .disabled(pins.pinCount(in: .all, excludingHidden: isOptionHeld) == 0)

                Button("Close All Hidden Pins") {
                    pins.closeHiddenPins()
                }
                .disabled(pins.hiddenPinCount == 0)
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
        .onAppear(perform: startWatchingOption)
        .onDisappear(perform: stopWatchingOption)
    }

    private func chooseImageFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.resolvesAliases = true

        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            guard response == .OK else { return }
            pins.pinExternalImages(at: panel.urls)
        }
    }

    /// A global flags-changed monitor would require Accessibility permission. Poll the
    /// free static snapshot only while the menu is presented, including menu-tracking mode.
    private func startWatchingOption() {
        guard optionWatcher == nil else { return }
        isOptionHeld = NSEvent.modifierFlags.contains(.option)
        let watcher = Timer(timeInterval: 0.08, repeats: true) { _ in
            MainActor.assumeIsolated {
                isOptionHeld = NSEvent.modifierFlags.contains(.option)
            }
        }
        RunLoop.main.add(watcher, forMode: .common)
        optionWatcher = watcher
    }

    private func stopWatchingOption() {
        optionWatcher?.invalidate()
        optionWatcher = nil
        isOptionHeld = false
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
