# Menubench distribution

Menubench is distributed directly as a signed and notarized universal macOS app. The GitHub Release workflow produces both a versioned DMG and the stable `Menubench.dmg` URL used by the README, updater and Homebrew Cask.

## Release identity

- App: `Menubench.app`
- Bundle identifier: `com.celikugurdev.menubench`
- Minimum macOS: 14 Sonoma
- Architectures: Apple silicon and Intel
- Signing: Developer ID Application
- Notarization: App Store Connect API key

Open `Menubench.xcodeproj` and keep the Menubench app and fan-control helper on the same Apple Developer Team. Release signing deliberately derives the Team ID from the certificate; no previous maintainer identity is embedded in the updater or CI.

## GitHub Actions secrets

Create a protected GitHub environment named `release-signing`, then add these repository or environment secrets:

| Secret | Value |
|---|---|
| `SIGNING_CERT_P12` | Base64-encoded Developer ID Application certificate exported from Keychain Access, including its private key |
| `SIGNING_CERT_PASSWORD` | Password used while exporting the `.p12` |
| `NOTARY_API_KEY_P8` | Base64-encoded App Store Connect API key file |
| `NOTARY_KEY_ID` | App Store Connect key ID |
| `NOTARY_ISSUER_ID` | App Store Connect issuer UUID |

Encode the binary files without putting their contents in shell history:

```sh
base64 -i DeveloperID.p12 | pbcopy
base64 -i AuthKey.p8 | pbcopy
```

Paste each clipboard value into the matching GitHub Actions secret.

## Publish a release

1. Update `MARKETING_VERSION` in both Release and Debug configurations of `Menubench.xcodeproj`.
2. Add a dated `## [MAJOR.MINOR.PATCH]` entry to `CHANGELOG.md` and `Resources/MenubenchCHANGELOG.md`.
3. Merge the release commit into `main`.
4. Create and push a stable semantic-version tag:

```sh
git tag -s v1.0.0 -m "Menubench 1.0.0"
git push origin v1.0.0
```

The workflow then:

1. verifies the tag, version and changelog;
2. runs unit tests;
3. builds a universal app with Xcode;
4. signs the helper and app with Developer ID;
5. notarizes and staples the app;
6. creates, signs, notarizes and verifies the DMG;
7. publishes `Menubench-1.0.0.dmg`, `Menubench.dmg` and checksums in a GitHub Release.

The workflow accepts final `vMAJOR.MINOR.PATCH` tags only and does not create a pre-release channel.

## Homebrew

`Casks/menubench.rb` turns this repository into a custom tap. It downloads the stable latest-release asset and installs `yt-dlp`, FFmpeg and Deno as formula dependencies.

```sh
brew tap augrclk/menubench https://github.com/augrclk/menubench
brew install --cask augrclk/menubench/menubench
```

The Cask uses the notarized app signature as the stable publisher boundary. Test it after every release:

```sh
brew uninstall --cask menubench 2>/dev/null || true
brew install --cask augrclk/menubench/menubench
brew audit --cask --online augrclk/menubench/menubench
```

## Manual local release check

If you are validating from Xcode before publishing:

```sh
xcodebuild \
  -project Menubench.xcodeproj \
  -scheme Menubench \
  -configuration Release \
  -derivedDataPath build/LocalRelease \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  build
```

Verify the archive or exported app shows your Developer ID and team:

```sh
codesign --verify --deep --strict --verbose=2 /path/to/Menubench.app
codesign -dv --verbose=4 /path/to/Menubench.app
lipo -archs /path/to/Menubench.app/Contents/MacOS/Menubench
```

Never publish an ad-hoc signed app. Test the final GitHub DMG on a clean macOS account by dragging the app to Applications, completing onboarding, checking updates and exercising link downloads with media you are permitted to save.
