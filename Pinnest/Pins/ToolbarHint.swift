//
//  ToolbarHint.swift
//  Pinnest
//

/// Identifies the toolbar control the pointer is over.
///
/// The hint bar tracks *which control* rather than a captured string, so text derived
/// from state — "Piercing on" versus "Piercing off" — updates the moment the state
/// changes instead of waiting for the pointer to leave and come back.
///
/// Close and the drag handle are deliberately absent: their appearance already says
/// what they do.
enum ToolbarHint: Hashable, CaseIterable {
    case copy
    case rotate
    case reset
    case scale
    case opacity
    case piercing

    func text(isPiercing: Bool) -> String {
        switch self {
        case .copy: "Copy image"
        case .rotate: "Rotate — hold ⇧ to reverse"
        case .reset: "Reset size & opacity"
        case .scale: "Scale — drag, or click to type"
        case .opacity: "Opacity — drag, or click to type"
        case .piercing: isPiercing ? "Piercing on — clicks pass through" : "Piercing off — image takes clicks"
        }
    }
}
