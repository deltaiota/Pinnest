//
//  SoftwareUpdateConfigurationTests.swift
//  PinnestTests
//

import Foundation
import Testing

struct SoftwareUpdateConfigurationTests {
    @Test func sparkleUsesSignedAutomaticChecks() throws {
        let info = try #require(Bundle.main.infoDictionary)

        #expect(
            info["SUFeedURL"] as? String ==
                "https://github.com/deltaiota/Pinnest/releases/latest/download/appcast.xml"
        )
        #expect(info["SUEnableAutomaticChecks"] as? Bool == true)
        #expect(info["SUAutomaticallyUpdate"] as? Bool == false)
        #expect(info["SUVerifyUpdateBeforeExtraction"] as? Bool == true)
        #expect(info["SURequireSignedFeed"] as? Bool == true)

        let publicKey = try #require(info["SUPublicEDKey"] as? String)
        #expect(Data(base64Encoded: publicKey)?.count == 32)
    }

    @Test func appMetadataSupportsMenuAndAboutLabels() throws {
        let info = try #require(Bundle.main.infoDictionary)
        #expect(info["CFBundleDisplayName"] as? String == "Pinnest")
        #expect(info["CFBundleShortVersionString"] as? String == "1.0.3")
        #expect(info["CFBundleVersion"] as? String == "4")
    }

    @Test func appDeclaresImageViewerSupport() throws {
        let info = try #require(Bundle.main.infoDictionary)
        let documentTypes = try #require(info["CFBundleDocumentTypes"] as? [[String: Any]])
        let imageType = try #require(documentTypes.first)
        #expect(imageType["CFBundleTypeRole"] as? String == "Viewer")
        #expect(imageType["LSHandlerRank"] as? String == "Alternate")
        #expect((imageType["LSItemContentTypes"] as? [String])?.contains("public.image") == true)
    }

    @Test func appEmbedsImageShareExtension() throws {
        let pluginsURL = try #require(Bundle.main.builtInPlugInsURL)
        let extensionURL = pluginsURL.appendingPathComponent("Pin with Pinnest.appex", isDirectory: true)
        let extensionBundle = try #require(Bundle(url: extensionURL))
        let info = try #require(extensionBundle.infoDictionary)
        let extensionInfo = try #require(info["NSExtension"] as? [String: Any])
        let attributes = try #require(extensionInfo["NSExtensionAttributes"] as? [String: Any])
        let activation = try #require(attributes["NSExtensionActivationRule"] as? [String: Any])

        #expect(extensionBundle.bundleIdentifier == "d.iota.Pinnest.PinWithPinnest")
        #expect(extensionInfo["NSExtensionPointIdentifier"] as? String == "com.apple.share-services")
        #expect(activation["NSExtensionActivationSupportsImageWithMaxCount"] as? Int == 100)
    }
}
