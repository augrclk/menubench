# Privacy

Menubench is local-first. It has no account, advertising, analytics, telemetry or remote crash reporter. System readings, clipboard items, window information, screenshots, recordings, media processing and app settings stay on your Mac.

## When Menubench uses the network

Network activity belongs to a visible feature:

1. **Updates.** Menubench checks the public GitHub Releases API for `augrclk/menubench`. The request contains the app name and version as a standard user agent, not a personal identifier. Automatic checks can be disabled in Settings.
2. **Link downloads.** When you start a permitted download, the locally installed `yt-dlp` process contacts the link's provider and FFmpeg performs local merging or conversion. Menubench does not proxy or log the URL.
3. **Network quality test.** A manual test transfers temporary data to measurement endpoints to calculate latency, download speed and upload speed. It starts only when you press the test button.
4. **Homebrew and app update checks.** These optional tools run local package-manager commands or read public update catalogs, which may contact Homebrew, GitHub, the Mac App Store and software vendors.
5. **Remote content requested by a tool.** Examples include fetching a website icon for a radial-menu shortcut or opening a link you selected.

Menubench-owned upload, feedback and temporary sharing services are disabled. Screenshots and recordings are not uploaded by the app.

## Local data

Settings use macOS preferences. Features such as clipboard history, snippets, scratchpads, recent captures and download jobs store only what their interface describes. You can turn those features off, clear their content or remove Menubench and its data with `Tools/uninstall.sh`.

## Permissions

Every macOS permission is optional and tied to a feature. Menubench explains the reason before requesting access and continues with the remaining tools if you decline. See [Permissions](PERMISSIONS.md) for the feature-by-feature list.

## Questions

Open a [GitHub issue](https://github.com/augrclk/menubench/issues) or read [Support](../SUPPORT.md). Do not include private URLs, clipboard content, file paths or unredacted screenshots in a public report.
