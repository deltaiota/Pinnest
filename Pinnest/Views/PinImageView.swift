//
//  PinImageView.swift
//  Pinnest
//

import AppKit
import SFSafeSymbols
import SwiftUI

struct PinImageView: View {
    let state: PinState
    unowned let controller: PinController

    var body: some View {
        if state.isHiddenIndicatorVisible {
            HiddenPinIndicator(state: state, controller: controller)
        } else {
            // Sized from the view's own bounds rather than from `state`, so the window
            // remains the single source of truth during animated transforms.
            GeometryReader { proxy in
                let box = proxy.size
                let unrotated = state.quarterTurns.isMultiple(of: 2)
                    ? box
                    : CGSize(width: box.height, height: box.width)

                Image(nsImage: state.image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: unrotated.width, height: unrotated.height)
                    .rotationEffect(state.rotation)
                    .frame(width: box.width, height: box.height)
                    .opacity(state.opacity)
            }
            .clipped()
            .overlay {
                if !state.isHidden {
                    WindowDragArea(
                        onDrag: { controller.move(by: $0) },
                        onScroll: { controller.handleScroll($0) }
                    )
                }
            }
        }
    }
}

/// A separate interaction surface keeps the hidden pin from exposing the image's
/// scroll catcher or native window drag loop. Its drag deltas are measured in fixed
/// screen coordinates by `WindowDragArea`, so moving its window cannot feed back into
/// the gesture.
private struct HiddenPinIndicator: View {
    let state: PinState
    unowned let controller: PinController

    @State private var isHovering = false

    var body: some View {
        ZStack {
            Circle()
                .fill(.thickMaterial)

            Image(nsImage: state.image)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .opacity(isHovering ? 1 : 0)
                .scaleEffect(isHovering ? 1 : 0.72)

            Image(systemSymbol: .pinFill)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .opacity(isHovering ? 0 : 1)
                .scaleEffect(isHovering ? 0.72 : 1)
        }
        .overlay(Circle().strokeBorder(.separator, lineWidth: 0.5))
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        .contentShape(Circle())
        .animation(.easeOut(duration: 0.14), value: isHovering)
        .overlay {
            WindowDragArea(
                onDrag: { controller.move(by: $0) },
                onClick: { controller.restore() },
                onHover: { isHovering = $0 }
            )
            .clipShape(Circle())
        }
    }
}
