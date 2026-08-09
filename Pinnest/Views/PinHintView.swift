//
//  PinHintView.swift
//  Pinnest
//

import SwiftUI

/// The floating hint bar. It is a window of its own so the toolbar never changes size
/// under the pointer, and it never takes mouse events.
struct PinHintView: View {
    let hint: ToolbarHint
    let isPiercing: Bool
    let isStubborn: Bool

    var body: some View {
        hint.label(isPiercing: isPiercing, isStubborn: isStubborn)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.separator, lineWidth: 0.5))
            .accessibilityLabel(hint.plainText(isPiercing: isPiercing, isStubborn: isStubborn))
    }
}
