//
//  ToolbarNumberField.swift
//  Pinnest
//

import SFSafeSymbols
import SwiftUI

/// Shows a percentage next to the icon for what it controls. Dragging adjusts it
/// without ever taking focus; clicking opens a field for an exact number, which is the
/// only moment Pinnest needs the keyboard.
struct ToolbarNumberField: View {
    let symbol: SFSymbol
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
            Image(systemSymbol: symbol)
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
                Text(verbatim: Self.format(value) + "%")
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
