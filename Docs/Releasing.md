# Releasing Pinnest

Pinnest updates are distributed through GitHub Releases and authenticated by Sparkle EdDSA. Release applications are intentionally Apple-unsigned, matching Elapse Recorder's release model; the Sparkle signature is the update trust anchor.

## One-time repository setup

Resolve Sparkle into a deterministic local directory so its command-line tools are easy to locate, then generate a Pinnest-specific key pair:

```sh
mkdir -p build
xcodebuild -resolvePackageDependencies \
  -project Pinnest.xcodeproj \
  -scheme Pinnest \
  -clonedSourcePackagesDirPath "$PWD/build/SourcePackages"

KEY_TOOL="$PWD/build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys"

$KEY_TOOL --account d.iota.Pinnest
$KEY_TOOL --account d.iota.Pinnest -p
$KEY_TOOL --account d.iota.Pinnest -x Pinnest.sparkle.private-key
```

The first command creates or retrieves the key in the login Keychain. The second prints the public key. The third exports the private key.

Configure the public GitHub repository:

- Repository variable `SPARKLE_PUBLIC_ED_KEY`: exact output from `generate_keys -p`
- Repository secret `SPARKLE_PRIVATE_ED_KEY`: exact contents of `Pinnest.sparkle.private-key`

The public key must be a base64-encoded 32-byte Ed25519 key. Never commit the private key, upload it as a release asset, or rotate it after publishing unless every supported client is deliberately migrated.

Local builds use a valid-shaped placeholder public key. The release workflow rejects that placeholder.

## Publishing a version

1. Update `MARKETING_VERSION` consistently across the Xcode project.
2. Increment `CURRENT_PROJECT_VERSION` to one integer, consistently across the project.
3. Add optional Markdown release notes at `ReleaseNotes/<version>.md`.
4. Commit the version and release notes.
5. Create and push a matching tag:

```sh
git tag v1.0
git push origin main v1.0
```

The workflow validates that `v1.0` matches `MARKETING_VERSION = 1.0` before producing a release.

## Workflow output

The tag-driven workflow:

1. Selects Xcode 26.3 / Swift 6.2 on the macOS 26 runner.
2. Validates both Sparkle keys and the public-key length.
3. Builds `Pinnest.app` in Release with Apple signing disabled.
4. Removes any linker-generated ad-hoc host signature.
5. Verifies the embedded Sparkle public key, version, and build number.
6. Packages `Pinnest-<version>.zip`.
7. Creates or updates a draft GitHub Release.
8. Generates a signed `appcast.xml` with Sparkle's `generate_appcast`.
9. Validates the XML and requires Sparkle's trailing whole-feed `sparkle-signatures` EdDSA block.
10. Uploads the appcast and publishes the release.

The app checks:

```text
https://github.com/deltaiota/Pinnest/releases/latest/download/appcast.xml
```

The initial downloaded application is Apple-unsigned, so macOS may require the user to approve the first launch through Finder's **Open** action or System Settings → Privacy & Security. Subsequent in-app updates are authenticated by Sparkle EdDSA.
