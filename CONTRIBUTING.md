# Contributing to Menubench

Menubench welcomes focused fixes, thoughtful utility improvements, translations and documentation work. Keep changes small enough to review and test on real Mac hardware.

## Set up

You need macOS 14 or newer and Xcode. Downloader development also uses Homebrew packages:

```sh
git clone https://github.com/augrclk/menubench.git
cd menubench
brew install yt-dlp ffmpeg deno
open Menubench.xcodeproj
```

Select your own Apple Development team in Xcode. The shared **Menubench** scheme builds both the app and its fan-control helper. A Developer ID is not required for local development.

The command-line build is useful for quick checks:

```sh
./build.sh --dev
./build/MenubenchDeveloper --selftest
./build.sh --test
```

## Before a pull request

- Explain the user problem, not only the code change.
- Test the exact interaction you changed on macOS 14 or newer.
- Keep new permissions, background work, dependencies and network requests explicit.
- Add every user-facing string to all supported localizations.
- Include a real screenshot for a visible interface change.
- Do not commit signing certificates, API keys, downloaded media or personal paths.

For link-download tests, use content you own or have permission to save. Tests should never depend on a specific copyrighted public video remaining online.

## Design direction

Menubench should feel native, calm and compact. Prefer clear hierarchy, restrained color, system materials and progressive disclosure. A utility should earn its space in the menu panel and remain fully removable from the active feature set.

## Reports and ideas

Use the [issue forms](https://github.com/augrclk/menubench/issues/new/choose). Security issues belong in a [private advisory](https://github.com/augrclk/menubench/security/advisories/new), never a public issue.

By contributing, you agree that your contribution is distributed under GPL-3.0-or-later and that existing copyright notices remain intact.
