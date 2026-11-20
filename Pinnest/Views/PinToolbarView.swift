//
//  PinToolbarView.swift
//  Pinnest
//

import AppKit
import SFSafeSymbols
import SwiftUI

struct PinToolbarView: View {
    let state: PinState
    unowned let controller: PinController

    var body: some View {
        HStack(spacing: 4) {
            CloseButton { controller.close() }
            HideButton { controller.hide() }

            CopyDragButton(controller: controller)

            RotateButton(controller: controller)

            ToolbarButton(symbol: .arrowCounterclockwise, hint: .reset, controller: controller) {
                controller.reset()
            }

            separator
            ToolbarNumberField(
                symbol: .arrowUpLeftAndArrowDownRight,
                hint: .scale,
                value: state.scale,
                range: state.scaleRange,
                controller: controller
            ) { controller.setScale($0) }
            ToolbarNumberField(
                symbol: .circleLefthalfFilled,
                hint: .opacity,
                value: state.opacity,
                range: PinGeometry.opacityRange,
                controller: controller
            ) { controller.setOpacity($0) }

            separator

            ToggleSymbolButton(
                symbol: piercingSymbol,
                hint: .piercing,
                controller: controller
            ) { controller.togglePiercing() }

            ToggleSymbolButton(
                symbol: state.isStubborn ? .lockFill : .lockSlashFill,
                hint: .stubborn,
                controller: controller
            ) { controller.toggleStubborn() }

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

    /// Piercing is intentionally the exception to the filled-toggle treatment: the
    /// plain pointer is clearer than a boxed pointer. On is unobstructed; off is slash.
    private var piercingSymbol: SFSymbol {
        if #available(macOS 26.0, *) {
            state.isPiercing ? .pointerArrow : .pointerArrowSlash
        } else {
            SFSymbol(rawValue: state.isPiercing ? "cursorarrow" : "cursorarrow.slash")
        }
    }
}

/// The window close button, borrowed wholesale: a red disc that only shows its glyph
/// when the pointer is on the toolbar. It needs no hint — everyone already knows it.
private struct CloseButton: View {
    let action: () -> Void

    @State private var isHovering = false
    @State private var animationTrigger = 0
    @State private var isClosing = false

    var body: some View {
        Button {
            guard !isClosing else { return }
            isClosing = true
            animationTrigger += 1
            // Keep the window alive long enough for the requested bounce to be visible.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: action)
        } label: {
            Circle()
                .fill(Color(red: 1, green: 0.37, blue: 0.34))
                .overlay(Circle().strokeBorder(.black.opacity(0.12), lineWidth: 0.5))
                .overlay {
                    Image(systemSymbol: .xmark)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.black.opacity(isHovering ? 0.55 : 0))
                        .symbolEffect(.bounce, value: animationTrigger)
                }
                .frame(width: 12, height: 12)
                .frame(width: 22, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

/// Mirrors the yellow macOS traffic-light control. Like minimise, the horizontal
/// glyph appears on hover; the short bounce completes before the pin collapses.
private struct HideButton: View {
    let action: () -> Void

    @State private var isHovering = false
    @State private var animationTrigger = 0
    @State private var isHiding = false

    var body: some View {
        Button {
            guard !isHiding else { return }
            isHiding = true
            animationTrigger += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                isHiding = false
                action()
            }
        } label: {
            Circle()
                .fill(Color(red: 1, green: 0.74, blue: 0.18))
                .overlay(Circle().strokeBorder(.black.opacity(0.12), lineWidth: 0.5))
                .overlay {
                    Image(systemSymbol: .minus)
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.black.opacity(isHovering ? 0.55 : 0))
                        .symbolEffect(.bounce, value: animationTrigger)
                }
                .frame(width: 12, height: 12)
                .frame(width: 22, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

/// Rectangular by design: six-dot grips on both sides distinguish this from a normal
/// click-only button. A click copies; crossing the drag threshold promises a PNG file.
private struct CopyDragButton: View {
    unowned let controller: PinController

    @State private var isHovering = false
    @State private var animationTrigger = 0

    var body: some View {
        CopyDragArea(
            image: { controller.renderedImage() },
            onClick: {
                animationTrigger += 1
                controller.copyImage()
            }
        )
        .frame(width: 58, height: 20)
        .background(
            isHovering ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
            in: RoundedRectangle(cornerRadius: 5)
        )
        .overlay {
            HStack(spacing: 3) {
                SixDotGrip()
                Image(systemSymbol: .documentOnDocument)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .symbolEffect(.bounce, value: animationTrigger)
                SixDotGrip()
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            controller.setHint(hovering ? .copy : nil)
        }
    }
}

/// Two rotated `ellipsis` symbols: three dots each, six total, the SF Symbols version
/// of a compact `::` drag affordance.
private struct SixDotGrip: View {
    var body: some View {
        HStack(spacing: -2) {
            dotColumn
            dotColumn
        }
        .foregroundStyle(.secondary)
    }

    private var dotColumn: some View {
        Image(systemSymbol: .ellipsis)
            .font(.system(size: 7, weight: .semibold))
            .rotationEffect(.degrees(90))
            .frame(width: 5, height: 12)
    }
}

/// Rotates clockwise, counterclockwise while shift is held. The icon follows the live
/// modifier state and wiggles in the direction the image is about to turn.
private struct RotateButton: View {
    unowned let controller: PinController

    @State private var isShiftDown = false
    @State private var isHovering = false
    @State private var shiftWatcher: Timer?
    @State private var clockwiseAnimationTrigger = 0
    @State private var counterclockwiseAnimationTrigger = 0

    var body: some View {
        Button {
            let counterclockwise = NSEvent.modifierFlags.contains(.shift)
            if counterclockwise {
                counterclockwiseAnimationTrigger += 1
            } else {
                clockwiseAnimationTrigger += 1
            }
            controller.rotate(clockwise: !counterclockwise)
        } label: {
            Image(systemSymbol: isShiftDown ? .rotateLeft : .rotateRight)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 22, height: 20)
                .background(
                    isHovering ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 5)
                )
                .contentShape(Rectangle())
                .symbolEffect(.wiggle.clockwise, value: clockwiseAnimationTrigger)
                .symbolEffect(.wiggle.counterClockwise, value: counterclockwiseAnimationTrigger)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .onHover { hovering in
            isHovering = hovering
            controller.setHint(hovering ? .rotate : nil)
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

/// Ordinary action button: one click, one bounce, one action.
private struct ToolbarButton: View {
    let symbol: SFSymbol
    let hint: ToolbarHint
    unowned let controller: PinController
    let action: () -> Void

    @State private var isHovering = false
    @State private var animationTrigger = 0

    var body: some View {
        Button {
            animationTrigger += 1
            action()
        } label: {
            Image(systemSymbol: symbol)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 22, height: 20)
                .background(
                    isHovering ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 5)
                )
                .contentShape(Rectangle())
                .symbolEffect(.bounce, value: animationTrigger)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .onHover { hovering in
            isHovering = hovering
            controller.setHint(hovering ? hint : nil)
        }
    }
}

/// State switch: no accent tint and no bounce. The slash appears or disappears through
/// SF Symbols' layer-aware magic-replace transition.
private struct ToggleSymbolButton: View {
    let symbol: SFSymbol
    let hint: ToolbarHint
    unowned let controller: PinController
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.22)) {
                action()
            }
        } label: {
            Image(systemSymbol: symbol)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 22, height: 20)
                .background(
                    isHovering ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
                    in: RoundedRectangle(cornerRadius: 5)
                )
                .contentShape(Rectangle())
                .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp)))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .onHover { hovering in
            isHovering = hovering
            controller.setHint(hovering ? hint : nil)
        }
    }
}

/// No hint: the grabbed-hand cursor and six dots already say "drag me".
private struct DragHandle: View {
    unowned let controller: PinController

    var body: some View {
        WindowDragArea(onDrag: { delta in controller.move(by: delta) })
            .frame(width: 24, height: 20)
            .overlay {
                SixDotGrip()
                    .allowsHitTesting(false)
            }
    }
}
