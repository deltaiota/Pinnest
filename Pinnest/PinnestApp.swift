//
//  PinnestApp.swift
//  Pinnest
//
//  Created by KrLite on 2026/7/29.
//

import Sparkle
import SwiftUI

@main
struct PinnestApp: App {
    @NSApplicationDelegateAdaptor(PinnestApplicationDelegate.self) private var applicationDelegate
    @State private var pins = PinManager.shared
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
        MenuBarExtra {
            MenuBarContent(
                pins: pins,
                clipboard: clipboard,
                updater: updaterController.updater
            )
        } label: {
            MenuBarDropTarget(pins: pins)
        }
        .menuBarExtraStyle(.menu)
    }
}

struct AboutMenuButton: View {
    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Pinnest"
    }

    var body: some View {
        Button("About \(appName)") {
            AboutWindowPresenter.shared.show()
        }
    }
}
