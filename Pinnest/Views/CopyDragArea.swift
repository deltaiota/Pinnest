//
//  CopyDragArea.swift
//  Pinnest
//

import AppKit
import SwiftUI

/// A click copies; moving beyond the system-style drag threshold starts a promised PNG
/// file drag. AppKit owns the gesture so click and drag cannot both fire.
struct CopyDragArea: NSViewRepresentable {
    let image: () -> NSImage
    let onClick: () -> Void

    func makeNSView(context _: Context) -> CopyDragView {
        let view = CopyDragView()
        view.image = image
        view.onClick = onClick
        return view
    }

    func updateNSView(_ view: CopyDragView, context _: Context) {
        view.image = image
        view.onClick = onClick
    }
}

final class CopyDragView: NSView, NSDraggingSource {
    var image: (() -> NSImage)?
    var onClick: (() -> Void)?

    private static let dragThreshold: CGFloat = 4
    private var mouseDownEvent: NSEvent?
    private var mouseDownLocation: CGPoint?
    private var startedDrag = false
    private var activePromise: ImageFilePromise?

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        mouseDownLocation = NSEvent.mouseLocation
        startedDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard
            !startedDrag,
            let start = mouseDownLocation,
            let mouseDownEvent
        else { return }

        let location = NSEvent.mouseLocation
        guard hypot(location.x - start.x, location.y - start.y) >= Self.dragThreshold else {
            return
        }
        guard let image = image?() else {
            NSSound.beep()
            return
        }

        do {
            let promise = try ImageFilePromise(image: image)
            let provider = promise.provider()
            // NSFilePromiseProvider's delegate is not ownership. `userInfo` keeps the
            // promise alive until Finder has requested and written the file.
            provider.userInfo = promise

            let item = NSDraggingItem(pasteboardWriter: provider)
            let previewSize = image.size.aspectFit(maximum: CGSize(width: 96, height: 96))
            let local = convert(mouseDownEvent.locationInWindow, from: nil)
            item.setDraggingFrame(
                CGRect(
                    x: local.x - previewSize.width / 2,
                    y: local.y - previewSize.height / 2,
                    width: previewSize.width,
                    height: previewSize.height
                ),
                contents: image
            )

            activePromise = promise
            startedDrag = true
            let session = beginDraggingSession(with: [item], event: event, source: self)
            session.animatesToStartingPositionsOnCancelOrFail = true
        } catch {
            NSSound.beep()
        }
    }

    override func mouseUp(with _: NSEvent) {
        defer { clearGesture() }
        guard !startedDrag else { return }
        onClick?()
    }

    func draggingSession(
        _: NSDraggingSession,
        sourceOperationMaskFor _: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }

    func draggingSession(_: NSDraggingSession, endedAt _: NSPoint, operation _: NSDragOperation) {
        // Do not clear `startedDrag` here. Depending on the destination, AppKit may
        // report session end before this view sees the trailing mouse-up; clearing it
        // would misclassify that mouse-up as a click and copy to the clipboard too.
        activePromise = nil
    }

    private func clearGesture() {
        mouseDownEvent = nil
        mouseDownLocation = nil
        startedDrag = false
        activePromise = nil
    }
}

extension CGSize {
    fileprivate func aspectFit(maximum: CGSize) -> CGSize {
        guard width > 0, height > 0 else { return maximum }
        let factor = min(maximum.width / width, maximum.height / height, 1)
        return CGSize(width: width * factor, height: height * factor)
    }
}
