//
//  PinToolbarView.swift
//  Pinnest
//

import AppKit
import SwiftUI

struct PinToolbarView: View {
    let state: PinState
    unowned let controller: PinController

    var body: some View {
        HStack(spacing: 4) {
            CloseButton { controller.close() }

            ToolbarButton(symbol: "doc.on.doc", hint: .copy, controller: controller) {
                controller.copyImage()
            }

            RotateButton(controller: controller)

            ToolbarButton(symbol: "arrow.counterclockwise", hint: .reset, controller: controller) {
                controller.reset()
            }

            separator

            NumberField(
                symbol: "arrow.up.left.and.arrow.down.right",
                hint: .scale,
                value: state.scale,
                range: PinGeometry.scaleRange,
                controller: controller
            ) { controller.setScale($0) }

            NumberField(
                symbol: "circle.lefthalf.filled",
                hint: .opacity,
                value: state.opacity,
                range: PinGeometry.opacityRange,
                controller: controller
            ) { controller.setOpacity($0) }

            separator

            ToolbarButton(
                symbol: state.isPiercing ? "cursorarrow.slash" : "cursorarrow",
                hint: .piercing,
                controller: controller,
                isOn: state.isPiercing
            ) { controller.togglePiercing() }

            DragHandle(controller: controller)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.separator, lineWidth: 0.5))
        .fixedSize()
    }

    private var separator: some View {
        Divider().frame(height: 14)
    }
}

/// The window close button, borrowed wholesale: a red disc that only shows its glyph
/// when the pointer is on the toolbar. It needs no hint — everyone already knows it.
private struct CloseButton: View {
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(red: 1, green: 0.37, blue: 0.34))
                .overlay(Circle().strokeBorder(.black.opacity(0.12), lineWidth: 0.5))
                .overlay {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.black.opacity(isHovering ? 0.55 : 0))
                }
                .frame(width: 12, height: 12)
                .frame(width: 22, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

/// Rotates clockwise, counterclockwise while shift is held. The icon follows the live
/// modifier state so the button always shows what it is about to do.
private struct RotateButton: View {
    unowned let controller: PinController

    @State private var isShiftDown = false
    @State private var isHovering = false
    @State private var shiftWatcher: Timer?

    var body: some View {
        ToolbarButton(
            symbol: isShiftDown ? "rotate.left" : "rotate.right",
            hint: .rotate,
            controller: controller
        ) {
            // SwiftUI hands button actions no modifiers, so the live flags are the only
            // way to tell a shift-click from a plain one.
            controller.rotate(clockwise: !NSEvent.modifierFlags.contains(.shift))
        }
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                startWatchingShift()
            } else {
                stopWatchingShift()
            }
        }
    }

    /// Polled rather than monitored: a global monitor for `.flagsChanged` counts as a
    /// key event and would need Accessibility permission, whereas `NSEvent`'s static
    /// snapshot is free. It only ticks while the pointer is on this button.
    private func startWatchingShift() {
        guard shiftWatcher == nil else { return }
        isShiftDown = NSEvent.modifierFlags.contains(.shift)
        shiftWatcher = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in
            MainActor.assumeIsolated {
                isShiftDown = NSEvent.modifierFlags.contains(.shift)
            }
        }
    }

    private func stopWatchingShift() {
        shiftWatcher?.invalidate()
        shiftWatcher = nil
        isShiftDown = false
    }
}

private struct ToolbarButton: View {
    let symbol: String
    let hint: ToolbarHint
    unowned let controller: PinController
    var isOn = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 22, height: 20)
                .background(
                    isHovering ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 5)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isOn ? Color.accentColor : .primary)
        .onHover { hovering in
            isHovering = hovering
            controller.setHint(hovering ? hint : nil)
        }
    }
}

/// Shows a percentage next to the icon for what it controls. Dragging adjusts it
/// without ever taking focus; clicking opens a field for an exact number, which is the
/// only moment Pinnest needs the keyboard.
private struct NumberField: View {
    let symbol: String
    let hint: ToolbarHint
    let value: CGFloat
    let range: ClosedRange<CGFloat>
    unowned let controller: PinController
    let onChange: (CGFloat) -> Void

    @State private var isEditing = false
    @State private var text = ""
    @State private var dragOrigin: CGFloat?
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)

            if isEditing {
                TextField("", text: $text)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .focused($isFocused)
                    .onSubmit(commit)
                    .onExitCommand(perform: finishEditing)
                    .onAppear {
                        text = Self.format(value)
                        isFocused = true
                    }
            } else {
                Text(Self.format(value) + "%")
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .font(.system(size: 11))
        .padding(.horizontal, 5)
        .frame(width: 64, height: 20)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 5))
        .contentShape(Rectangle())
        .onTapGesture(perform: beginEditing)
        .gesture(dragGesture)
        .onHover { controller.setHint($0 ? hint : nil) }
    }

    /// A vertical drag walks the value: 200 points of travel covers the whole range.
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { gesture in
                let origin = dragOrigin ?? value
                dragOrigin = origin
                onChange(origin - gesture.translation.height / 200)
            }
            .onEnded { _ in dragOrigin = nil }
    }

    private func beginEditing() {
        guard !isEditing else { return }
        controller.beginEditingNumber()
        isEditing = true
    }

    private func commit() {
        let cleaned = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "%", with: "")
        if let percent = Double(cleaned) {
            onChange(PinGeometry.clamp(CGFloat(percent) / 100, to: range))
        }
        finishEditing()
    }

    private func finishEditing() {
        isEditing = false
        isFocused = false
        controller.endEditingNumber()
    }

    private static func format(_ value: CGFloat) -> String {
        String(Int((value * 100).rounded()))
    }
}

/// No hint: the grabbed-hand cursor already says "drag me", which is the whole point of
/// changing it.
private struct DragHandle: View {
    unowned let controller: PinController

    var body: some View {
        WindowDragArea { delta in controller.move(by: delta) }
            .frame(width: 22, height: 20)
            .overlay {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)
            }
    }
}
