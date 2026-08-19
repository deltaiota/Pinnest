//
//  AboutWindowPresenter.swift
//  Pinnest
//

import AppKit
import SwiftUI

/// Hosts About outside the SwiftUI scene graph so a file-open launch cannot mistake it
/// for the app's default document window.
@MainActor
final class AboutWindowPresenter: NSObject, NSWindowDelegate {
    static let shared = AboutWindowPresenter()

    private var window: NSWindow?

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_: Notification) {
        window = nil
    }

    private func makeWindow() -> NSWindow {
        let hosting = NSHostingView(rootView: AboutView())
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: hosting.fittingSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = String(localized: "About Pinnest")
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.animationBehavior = .documentWindow
        window.delegate = self
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        return window
    }
}
