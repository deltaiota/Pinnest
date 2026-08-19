//
//  PinManager.swift
//  Pinnest
//

import AppKit
import Observation

enum PinCloseScope {
    case currentDesktop
    case otherDesktops
    case all
}

/// Owns every open pin and the single pointer monitor they share — one monitor for the
/// whole app rather than one per pin, and none at all while no pins are open.
@MainActor
@Observable
final class PinManager {
    static let shared = PinManager()

    private(set) var pins: [PinController] = []
    private var hoverMonitor: HoverMonitor?
    private var cascadeStep = 0

    /// Off only in tests: the monitor reports the *physical* pointer, so a test that
    /// drives hover by hand would otherwise be at the mercy of where the mouse happens
    /// to be sitting.
    private let hoverMonitoring: Bool

    init(hoverMonitoring: Bool = true) {
        self.hoverMonitoring = hoverMonitoring
    }

    var isEmpty: Bool {
        pins.isEmpty
    }

    func pinFromClipboard(from pasteboard: NSPasteboard = .general) {
        guard let image = ClipboardImage.read(from: pasteboard) else {
            NSSound.beep()
            return
        }
        pin(image)
    }

    func pinExternalImages(at urls: [URL]) {
        let centre = activeDisplayCentre()
        var pinnedImage = false

        for url in urls {
            guard let image = securelyLoadedImage(at: url) else { continue }
            pin(image, centredOn: centre)
            pinnedImage = true
        }

        if !pinnedImage {
            NSSound.beep()
        }
    }

    func pinExternalImage(_ image: NSImage) {
        pin(image, centredOn: activeDisplayCentre())
    }

    func pin(_ image: NSImage) {
        pin(image, centredOn: nextCentre())
    }

    private func pin(_ image: NSImage, centredOn centre: CGPoint) {
        let controller = PinController(image: image, centredOn: centre, manager: self)
        pins.append(controller)
        startHoverMonitorIfNeeded()
    }

    func closeAll() {
        for pin in pins {
            pin.close()
        }
    }

    func closePins(in scope: PinCloseScope, excludingHidden: Bool = false) {
        for pin in pins where pinMatches(pin, scope: scope, excludingHidden: excludingHidden) {
            pin.close()
        }
    }

    func pinCount(in scope: PinCloseScope, excludingHidden: Bool = false) -> Int {
        pins.lazy.filter { self.pinMatches($0, scope: scope, excludingHidden: excludingHidden) }.count
    }

    func closeHiddenPins() {
        for pin in pins where pin.isHidden {
            pin.close()
        }
    }

    var hiddenPinCount: Int {
        pins.lazy.filter(\.isHidden).count
    }

    private func pinMatches(
        _ pin: PinController,
        scope: PinCloseScope,
        excludingHidden: Bool
    ) -> Bool {
        guard !excludingHidden || !pin.isHidden else { return false }
        switch scope {
        case .currentDesktop:
            return pin.isOnActiveSpace
        case .otherDesktops:
            return !pin.isOnActiveSpace
        case .all:
            return true
        }
    }

    func remove(_ controller: PinController) {
        pins.removeAll { $0 == controller }
        if pins.isEmpty {
            hoverMonitor = nil
            cascadeStep = 0
        }
    }

    /// Pins land on the screen the pointer is on, stepped diagonally so a burst of
    /// them doesn't stack into a single indistinguishable pile.
    private func nextCentre() -> CGPoint {
        let frame = activeScreen()?.visibleFrame ?? .zero
        let offset = CGFloat(cascadeStep % 6) * 28
        cascadeStep += 1
        return CGPoint(x: frame.midX + offset, y: frame.midY - offset)
    }

    private func activeDisplayCentre() -> CGPoint {
        guard let frame = activeScreen()?.visibleFrame else { return .zero }
        return CGPoint(x: frame.midX, y: frame.midY)
    }

    private func activeScreen() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
    }

    private func securelyLoadedImage(at url: URL) -> NSImage? {
        guard url.isFileURL else { return nil }

        let hasSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: url),
              let image = NSImage(data: data),
              image.isValid
        else {
            return nil
        }
        return image
    }

    private func startHoverMonitorIfNeeded() {
        guard hoverMonitoring, hoverMonitor == nil else { return }
        hoverMonitor = HoverMonitor { [weak self] location in
            guard let self else { return }
            for pin in pins {
                pin.updateHover(at: location)
            }
        }
    }
}
