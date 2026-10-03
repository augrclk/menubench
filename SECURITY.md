# Security policy

## Reporting a vulnerability

Please do not publish security vulnerabilities in an issue, discussion or pull request. Use GitHub's [private vulnerability reporting](https://github.com/augrclk/menubench/security/advisories/new) so the maintainer can investigate and coordinate a fix before details become public.

Include the affected Menubench version, macOS version, expected impact, reproduction steps and a minimal proof of concept when possible. Remove unrelated private data.

## Supported versions

Security fixes target the latest public release. Confirm the issue still exists there before reporting it.

## Release integrity

Public DMGs are built by GitHub Actions, signed with the Menubench Developer ID identity and notarized by Apple. The self-updater accepts only an app and DMG signed by the same Apple Developer Team as the installed copy.

Reports about signature verification, update replacement, helper authorization, permission misuse, link handling or command construction are especially important.

## Security boundaries

- Imported Command Bar scripts remain disabled until the user reviews and explicitly approves each executable in Settings. Approval from a backup is never transferred to another Mac.
- Privileged fan control requires an Apple-issued signing identity with a valid Team ID. Ad hoc and local self-signed builds cannot register or authenticate the root helper.
- Automatic updates with administrator privileges are limited to `/Applications/Menubench.app`. The installer captures a bounded regular DMG into a private directory, verifies its signer before mounting it read-only, and verifies the app identity and offered version before replacing the installed bundle. Failed replacements preserve the previous app when rollback cannot finish.
- App-group cleanup requires a valid Apple signature and a group identifier in the signing team's namespace. Profile-authorized `group.*` identifiers are conservatively retained until provisioning-profile validation is supported.
- Full Disk Access probing starts when a cleaner, uninstaller or relevant permission surface opens. Camera, microphone, screen recording and Accessibility prompts belong to the features that use them.
- Menubench's Homebrew subprocesses disable Homebrew analytics.

## Automated checks

Pull requests and pushes to `main` run compatibility tests and a universal app build. CodeQL analyzes Swift and GitHub Actions with `security-extended` queries on pull requests, pushes and a weekly schedule. Dependabot configuration covers Swift packages and GitHub Actions; repository alerts and security updates are enabled separately in GitHub settings.

The regression suite exercises imported-script execution, signing requirements, app-group authority, bounded update snapshots and symlink-safe replacement without administrator authorization or live app installation.

## Verifying a release

Download `SHA256SUMS` alongside the public DMG and compare its SHA-256 before installation. Developer ID signing and Apple notarization are independent checks; a checksum alone does not establish publisher identity.

Malware scan results apply only to the exact published file hash and scan date. Do not treat CI results, notarization or multi-engine scan results as a guarantee that no vulnerability exists. External native macOS security review remains valuable for privileged helpers, updater replacement, TCC use and deletion boundaries.
