//
//  ToolbarHint.swift
//  Pinnest
//

import AppKit
import Foundation
import SFSafeSymbols
import SwiftUI

/// Identifies the toolbar control the pointer is over and renders its live, rich hint.
/// Close and the move grip are deliberately absent: their appearance already says what
/// they do.
enum ToolbarHint: Hashable, CaseIterable {
    case copy
    case rotate
    case reset
    case scale
    case opacity
    case piercing
    case stubborn

    @MainActor
    func label(isPiercing: Bool, isStubborn: Bool) -> Text {
        switch self {
        case .copy:
            (Self.pointer + Text(verbatim: " ") + Self
                .localized("Copy to clipboard") + Text(verbatim: " / ") +
                Self.symbol(.handPinch) + Text(verbatim: " ") + Self.localized("Drag as image file"))
                .bold()
        case .rotate:
            (Self.pointer + Text(verbatim: " ") + Self.localized("Rotate clockwise") + Text(verbatim: " / ") +
                Self.symbol(.shift) + Text(verbatim: " ") + Self.pointer + Text(verbatim: " ") +
                Self.localized("Rotate counterclockwise"))
                .bold()
        case .reset:
            (Self.pointer + Text(verbatim: " ") + Self.localized("Reset size, rotation & opacity"))
                .bold()
        case .scale:
            Self.localized("Scale").bold() + Text(verbatim: " — ") + Self.localized("drag, or click to type")
        case .opacity:
            Self.localized("Opacity").bold() + Text(verbatim: " — ") + Self
                .localized("drag, or click to type")
        case .piercing:
            Self.localized(isPiercing ? "Piercing on" : "Piercing off").bold() + Text(verbatim: " - ") +
                Self.localized(isPiercing ? "clicks pass through" : "image takes clicks")
        case .stubborn:
            Self.localized(isStubborn ? "Stubborn on" : "Stubborn off").bold() + Text(verbatim: " - ") +
                Self.localized(isStubborn
                    ? "image visible only on this Desktop"
                    : "image visible on every Desktop")
        }
    }

    func plainText(isPiercing: Bool, isStubborn: Bool) -> String {
        func string(_ resource: LocalizedStringResource) -> String {
            String(localized: resource)
        }

        switch self {
        case .copy: return "\(string("Copy to clipboard")) / \(string("Drag as image file"))"
        case .rotate: return "\(string("Rotate clockwise")) / Shift + \(string("Rotate counterclockwise"))"
        case .reset: return string("Reset size, rotation & opacity")
        case .scale: return "\(string("Scale")) — \(string("drag, or click to type"))"
        case .opacity: return "\(string("Opacity")) — \(string("drag, or click to type"))"
        case .piercing:
            let state = string(isPiercing ? "Piercing on" : "Piercing off")
            let detail = string(isPiercing ? "clicks pass through" : "image takes clicks")
            return "\(state) - \(detail)"
        case .stubborn:
            let state = string(isStubborn ? "Stubborn on" : "Stubborn off")
            let detail = string(isStubborn
                ? "image visible only on this Desktop"
                : "image visible on every Desktop")
            return "\(state) - \(detail)"
        }
    }

    private static func localized(_ resource: LocalizedStringResource) -> Text {
        Text(String(localized: resource))
    }

    private static func symbol(_ symbol: SFSymbol) -> Text {
        Text(Image(systemSymbol: symbol))
    }

    /// `pointer.arrow.rays` is the unfilled click pointer requested for hints. Before
    /// macOS 26 the same glyph is named `cursorarrow.rays`.
    private static var pointer: Text {
        let names = ["pointer.arrow.rays", "cursorarrow.rays"]
        let name = names.first { NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil }
            ?? "cursorarrow.rays"
        return symbol(SFSymbol(rawValue: name))
    }
}
