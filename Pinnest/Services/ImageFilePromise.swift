//
//  ImageFilePromise.swift
//  Pinnest
//

import AppKit
import UniformTypeIdentifiers

/// Encodes the image once, at drag start, then fulfills Finder's file promise only if
/// the user actually drops it. No temporary file is created for cancelled drags.
final class ImageFilePromise: NSObject, NSFilePromiseProviderDelegate, @unchecked Sendable {
    enum ExportError: Error {
        case pngEncodingFailed
    }

    private let data: Data
    private let fileName: String
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "Pinnest.ImageFilePromise"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()

    @MainActor
    init(image: NSImage, fileName: String? = nil) throws {
        guard
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff),
            let data = bitmap.representation(using: .png, properties: [:])
        else {
            throw ExportError.pngEncodingFailed
        }

        self.data = data
        self.fileName = fileName ?? String(localized: "Pinned Image.png")
    }

    @MainActor
    func provider() -> NSFilePromiseProvider {
        NSFilePromiseProvider(fileType: UTType.png.identifier, delegate: self)
    }

    @MainActor
    func filePromiseProvider(_: NSFilePromiseProvider, fileNameForType _: String) -> String {
        fileName
    }

    @MainActor
    func operationQueue(for _: NSFilePromiseProvider) -> OperationQueue {
        queue
    }

    nonisolated func filePromiseProvider(
        _: NSFilePromiseProvider,
        writePromiseTo url: URL,
        completionHandler: @escaping @Sendable ((any Error)?) -> Void
    ) {
        var coordinationError: NSError?
        var writeError: (any Error)?
        NSFileCoordinator().coordinate(
            writingItemAt: url,
            options: .forReplacing,
            error: &coordinationError
        ) { destination in
            do {
                try data.write(to: destination, options: .atomic)
            } catch {
                writeError = error
            }
        }
        completionHandler(writeError ?? coordinationError)
    }
}
