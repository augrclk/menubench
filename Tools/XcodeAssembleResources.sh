#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint

set -euo pipefail
cd "$SRCROOT"

app_bundle="$TARGET_BUILD_DIR/$WRAPPER_NAME"
app_resources="$app_bundle/Contents/Resources"
launch_daemons="$app_bundle/Contents/Library/LaunchDaemons"
helper_id="com.celikugurdev.menubench.fan-control"
helper_path="$app_bundle/Contents/Library/LaunchServices/$helper_id"
helper_plist="$launch_daemons/$helper_id.plist"
iconset="$DERIVED_FILE_DIR/MenubenchAppIcon.iconset"
icon_module_cache="$DERIVED_FILE_DIR/IconModuleCache"

mkdir -p "$app_resources" "$launch_daemons" "$iconset" "$icon_module_cache"

# Generate the exact selected icon plus its faithful menu-bar template mark.
export CLANG_MODULE_CACHE_PATH="$icon_module_cache"
export SWIFT_MODULE_CACHE_PATH="$icon_module_cache"
xcrun --sdk macosx swift Tools/MakeIcon.swift "$iconset"
cp "$DERIVED_FILE_DIR/MenuBarIcon.png" "$app_resources/MenuBarIcon.png"
cp "$DERIVED_FILE_DIR/MenuBarIcon@2x.png" "$app_resources/MenuBarIcon@2x.png"
cp "$DERIVED_FILE_DIR/BrandMark.png" "$app_resources/BrandMark.png"
cp Resources/Brand/MenubenchAppIcon.png "$app_resources/MenubenchAppIcon.png"
cp Resources/MenubenchCHANGELOG.md "$app_resources/CHANGELOG.md"

for localization in Resources/*.lproj(N); do
    ditto "$localization" "$app_resources/${localization:t}"
done
if [[ -d Resources/Gifs ]]; then
    ditto Resources/Gifs "$app_resources/Gifs"
fi
if [[ -d Resources/Images ]]; then
    ditto Resources/Images "$app_resources/Images"
fi

cp Resources/com.celikugurdev.menubench.fan-control.plist "$helper_plist"

# Registration is refreshed only when the embedded helper or its launchd
# contract changes. The command-line build stamps the same composite digest.
if [[ -f "$helper_path" ]]; then
    helper_version="$({
        export LC_ALL=C
        /usr/bin/shasum -a 256 "$helper_path" "$helper_plist" \
            | /usr/bin/awk '{print $1}' | /usr/bin/shasum -a 256 \
            | /usr/bin/awk '{print $1}'
    })"
    info_plist="$app_bundle/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Delete :MenubenchFanControlHelperVersion" "$info_plist" 2>/dev/null || true
    /usr/libexec/PlistBuddy -c "Add :MenubenchFanControlHelperVersion string $helper_version" "$info_plist"
fi
