//
//  ShareViewController.swift
//  Pin with Pinnest
//

import AppKit
import UniformTypeIdentifiers

final class ShareViewController: NSViewController {
    private var hasStarted = false

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard !hasStarted else { return }
        hasStarted = true

        Task {
            await deliverImagesToPinnest()
        }
    }

    private func deliverImagesToPinnest() async {
        guard let extensionContext else { return }

        do {
            let providers = imageProviders(from: extensionContext.inputItems)
            guard !providers.isEmpty else {
                throw ShareError.noImages
            }

            let stagingDirectory = try makeStagingDirectory()
            var stagedURLs: [URL] = []
            stagedURLs.reserveCapacity(providers.count)

            for provider in providers {
                if let stagedURL = await stageImage(from: provider, in: stagingDirectory) {
                    stagedURLs.append(stagedURL)
                }
            }

            guard !stagedURLs.isEmpty else {
                throw ShareError.couldNotReadImages
            }

            let applicationURL = try containingApplicationURL()
            try await open(stagedURLs, with: applicationURL)
            extensionContext.completeRequest(returningItems: nil, completionHandler: nil)
        } catch {
            extensionContext.cancelRequest(withError: error)
        }
    }

    private func imageProviders(from inputItems: [Any]) -> [NSItemProvider] {
        inputItems
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] }
            .filter { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }
    }

    private func makeStagingDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PinWithPinnest-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func stageImage(from provider: NSItemProvider, in directory: URL) async -> URL? {
        guard let typeIdentifier = provider.registeredTypeIdentifiers.first(where: {
            UTType($0)?.conforms(to: .image) == true
        }) else {
            return nil
        }

        if let fileURL = await stageFileRepresentation(
            from: provider,
            typeIdentifier: typeIdentifier,
            in: directory
        ) {
            return fileURL
        }

        if let dataURL = await stageDataRepresentation(
            from: provider,
            typeIdentifier: typeIdentifier,
            in: directory
        ) {
            return dataURL
        }

        return await stageImageObject(from: provider, in: directory)
    }

    private func stageFileRepresentation(
        from provider: NSItemProvider,
        typeIdentifier: String,
        in directory: URL
    ) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { sourceURL, _ in
                guard let sourceURL else {
                    continuation.resume(returning: nil)
                    return
                }

                let destinationURL = Self.uniqueStagingURL(
                    in: directory,
                    typeIdentifier: typeIdentifier,
                    sourceExtension: sourceURL.pathExtension
                )

                do {
                    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                    continuation.resume(returning: destinationURL)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func stageDataRepresentation(
        from provider: NSItemProvider,
        typeIdentifier: String,
        in directory: URL
    ) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, _ in
                guard let data else {
                    continuation.resume(returning: nil)
                    return
                }

                let destinationURL = Self.uniqueStagingURL(
                    in: directory,
                    typeIdentifier: typeIdentifier,
                    sourceExtension: nil
                )

                do {
                    try data.write(to: destinationURL, options: .atomic)
                    continuation.resume(returning: destinationURL)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func stageImageObject(from provider: NSItemProvider, in directory: URL) async -> URL? {
        guard provider.canLoadObject(ofClass: NSImage.self) else { return nil }

        return await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: NSImage.self) { object, _ in
                guard let image = object as? NSImage,
                      let data = image.tiffRepresentation
                else {
                    continuation.resume(returning: nil)
                    return
                }

                let destinationURL = Self.uniqueStagingURL(
                    in: directory,
                    typeIdentifier: UTType.tiff.identifier,
                    sourceExtension: nil
                )

                do {
                    try data.write(to: destinationURL, options: .atomic)
                    continuation.resume(returning: destinationURL)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private nonisolated static func uniqueStagingURL(
        in directory: URL,
        typeIdentifier: String,
        sourceExtension: String?
    ) -> URL {
        let fileExtension = sourceExtension.flatMap { $0.isEmpty ? nil : $0 }
            ?? UTType(typeIdentifier)?.preferredFilenameExtension
        let name = UUID().uuidString
        return directory.appendingPathComponent(
            fileExtension.map { "\(name).\($0)" } ?? name,
            isDirectory: false
        )
    }

    private func containingApplicationURL() throws -> URL {
        var candidate = Bundle.main.bundleURL.deletingLastPathComponent()

        while candidate.path != "/" {
            let isContainingApplication = candidate.pathExtension == "app" &&
                Bundle(url: candidate)?.bundleIdentifier == "d.iota.Pinnest"
            if isContainingApplication {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }

        throw ShareError.containingApplicationNotFound
    }

    private func open(_ urls: [URL], with applicationURL: URL) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            NSWorkspace.shared.open(
                urls,
                withApplicationAt: applicationURL,
                configuration: configuration
            ) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

private enum ShareError: LocalizedError {
    case noImages
    case couldNotReadImages
    case containingApplicationNotFound

    nonisolated var errorDescription: String? {
        switch self {
        case .noImages:
            "No image attachments were supplied."
        case .couldNotReadImages:
            "The shared images could not be read."
        case .containingApplicationNotFound:
            "The containing Pinnest application could not be found."
        }
    }
}
