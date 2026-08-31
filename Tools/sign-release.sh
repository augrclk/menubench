#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later

# Signs an Xcode-built universal Menubench bundle with the Developer ID
# Application identity available in the current keychain.
set -euo pipefail

APP="${1:-}"
if [[ -z "$APP" || ! -d "$APP" ]]; then
    echo "usage: sign-release.sh <Menubench.app>" >&2
    exit 1
fi

IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' \
    | head -n 1)"
if [[ -z "$IDENTITY" ]]; then
    echo "No Developer ID Application identity is available." >&2
    exit 1
fi

HELPER_ID="com.celikugurdev.menubench.fan-control"
HELPER="$APP/Contents/Library/LaunchServices/$HELPER_ID"

xattr -cr "$APP"

if [[ -f "$HELPER" ]]; then
    codesign --force --options runtime --timestamp \
        --identifier "$HELPER_ID" \
        --sign "$IDENTITY" \
        "$HELPER"
fi

codesign --force --options runtime --timestamp \
    --entitlements Resources/Menubench.entitlements \
    --sign "$IDENTITY" \
    "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"
TEAM_ID="$(codesign -dv --verbose=4 "$APP" 2>&1 \
    | awk -F= '/^TeamIdentifier=/{print $2; exit}')"
if [[ -z "$TEAM_ID" || "$TEAM_ID" == "not set" ]]; then
    echo "The signed app has no Apple Developer Team identifier." >&2
    exit 1
fi

echo "Signed Menubench with $IDENTITY (Team $TEAM_ID)."
