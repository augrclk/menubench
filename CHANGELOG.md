# Menubench Changelog

## [Unreleased]

### Security

- Require local approval before imported Command Bar scripts can run.
- Capture and verify updates in a private staging directory, use atomic bundle replacement and restrict administrator updates to the canonical Applications location.
- Require Apple signing identity and a Team ID for privileged fan control.
- Retain unverified and foreign-team app-group containers during app cleanup.
- Defer Full Disk Access probes until a relevant feature or permission screen opens and disable Homebrew subprocess analytics.
- Add Swift and GitHub Actions CodeQL scanning and adversarial regression tests.

## [1.0.1] - 2026-09-01

### Improvements

- Added automatic recovery for intermittent YouTube `HTTP 403` download failures.
- Menubench now retries the media connection, refreshes an outdated Homebrew `yt-dlp` installation when needed and resumes the download without asking the user to run Terminal commands.
- Added bounded HTTP and fragment retries, cancellable recovery steps and clear Turkish and English status messages.
- Kept permanent link and extractor errors visible instead of retrying them indefinitely.

## [1.0.0] - 2026-08-31

### Highlights

- Introduced the independent Menubench identity, selected app icon, menu-bar mark and refined interface.
- Added link downloads powered by `yt-dlp`, with MP4, MOV, MP3 and WAV output plus video and audio quality choices.
- Rebuilt network quality measurement around real download and upload transfers, latency samples and measured duration.
- Kept CPU, GPU, memory, disk, network, power and temperature readings connected to native macOS system sources.
- Prepared a universal Apple silicon and Intel build, Developer ID signing, Apple notarization, a polished DMG and Homebrew Cask distribution.
- Removed pre-release labeling from the public interface and release channel.

### Identity

- Application: Menubench
- Maintainer: Arif Uğur Çelik
- Bundle identifier: `com.celikugurdev.menubench`
