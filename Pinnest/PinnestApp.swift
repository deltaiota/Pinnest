//
//  PinnestApp.swift
//  Pinnest
//
//  Created by KrLite on 2026/7/29.
//

import SwiftUI

@main
struct PinnestApp: App {
    @State private var pins = PinManager()
    @State private var clipboard = ClipboardWatcher()

    var body: some Scene {
        MenuBarExtra("Pinnest", systemImage: "pin.fill") {
            MenuBarContent(pins: pins, clipboard: clipboard)
        }
    }
}
