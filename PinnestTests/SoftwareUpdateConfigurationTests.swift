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
        #expect(info["CFBundleShortVersionString"] as? String == "1.0")
        #expect(info["CFBundleVersion"] as? String == "1")
    }
}
