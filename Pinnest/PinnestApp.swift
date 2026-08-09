//
//  PinnestApp.swift
//  Pinnest
//
//  Created by KrLite on 2026/7/29.
//

import SFSafeSymbols
import Sparkle
import SwiftUI

@main
struct PinnestApp: App {
    static let aboutWindowID = "about"

    @State private var pins = PinManager()
    @State private var clipboard = ClipboardWatcher()
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    var body: some Scene {
        Window("About Pinnest", id: Self.aboutWindowID) {
            AboutView()
        }
        .windowResizability(.contentSize)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
        .defaultPosition(.center)
        .commands {
            CommandGroup(replacing: .appInfo) {
                AboutMenuButton()
            }
        }

        MenuBarExtra("Pinnest", systemSymbol: .mappinAndEllipse) {
            MenuBarContent(
                pins: pins,
                clipboard: clipboard,
                updater: updaterController.updater
            )
        }
        .menuBarExtraStyle(.menu)
    }
}

/// Native SwiftUI action shared by the standard App menu and menu-bar menu.
struct AboutMenuButton: View {
    @Environment(\.openWindow) private var openWindow

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Pinnest"
    }

    var body: some View {
        Button("About \(appName)") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: PinnestApp.aboutWindowID)
        }
    }
}
