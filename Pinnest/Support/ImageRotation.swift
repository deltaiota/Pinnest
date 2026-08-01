//
//  ImageRotation.swift
//  Pinnest
//

import AppKit

enum ImageRotation {
    /// Bakes quarter turns into a new image at full pixel resolution. Only the copy
    /// action needs this — on screen, SwiftUI's `rotationEffect` does the work for free.
    static func rotated(_ image: NSImage, quarterTurns: Int) -> NSImage {
        let turns = ((quarterTurns % 4) + 4) % 4
        guard turns != 0,
              let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return image }

        let width = source.width
        let height = source.height
        let swapped = !turns.isMultiple(of: 2)
        let outputWidth = swapped ? height : width
        let outputHeight = swapped ? width : height

        guard let context = CGContext(
            data: nil,
            width: outputWidth,
            height: outputHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }

        context.translateBy(x: CGFloat(outputWidth) / 2, y: CGFloat(outputHeight) / 2)
        context.rotate(by: -CGFloat(turns) * .pi / 2)
        context.translateBy(x: -CGFloat(width) / 2, y: -CGFloat(height) / 2)
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let output = context.makeImage() else { return image }
        return NSImage(cgImage: output, size: CGSize(width: outputWidth, height: outputHeight))
    }
}
