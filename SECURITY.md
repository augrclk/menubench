# Security policy

## Reporting a vulnerability

Please do not publish security vulnerabilities in an issue, discussion or pull request. Use GitHub's [private vulnerability reporting](https://github.com/augrclk/menubench/security/advisories/new) so the maintainer can investigate and coordinate a fix before details become public.

Include the affected Menubench version, macOS version, expected impact, reproduction steps and a minimal proof of concept when possible. Remove unrelated private data.

## Supported versions

Security fixes target the latest public release. Confirm the issue still exists there before reporting it.

## Release integrity

Public DMGs are built by GitHub Actions, signed with the Menubench Developer ID identity and notarized by Apple. The self-updater accepts only an app and DMG signed by the same Apple Developer Team as the installed copy.

Reports about signature verification, update replacement, helper authorization, permission misuse, link handling or command construction are especially important.
