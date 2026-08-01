//
//  PinManager.swift
//  Pinnest
//

import AppKit
import Observation

/// Owns every open pin and the single pointer monitor they share — one monitor for the
/// whole app rather than one per pin, and none at all while no pins are open.
@MainActor
@Observable
final class PinManager {
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

    func pin(_ image: NSImage) {
        let controller = PinController(image: image, centredOn: nextCentre(), manager: self)
        pins.append(controller)
        startHoverMonitorIfNeeded()
    }

    func closeAll() {
        for pin in pins {
            pin.close()
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
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        let frame = screen?.visibleFrame ?? .zero
        let offset = CGFloat(cascadeStep % 6) * 28
        cascadeStep += 1
        return CGPoint(x: frame.midX + offset, y: frame.midY - offset)
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
