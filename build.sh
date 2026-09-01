#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint

# Builds Menubench, assembles the .app bundle, signs it and (with --install)
# installs it into /Applications.
#
# The bundle is staged in a temporary directory outside ~/Documents: folders synced
# by File Provider gain xattrs (com.apple.provenance etc.) that invalidate codesign.
set -euo pipefail
cd "$(dirname "$0")"

# The icon catalog and the bundle are staged in temp dirs; sweep both however
# the script ends.
ICON_TMP=""
STAGE_TMP=""

cleanup() {
    [[ -n "$ICON_TMP" ]] && rm -rf "$ICON_TMP"
    [[ -n "$STAGE_TMP" ]] && rm -rf "$STAGE_TMP"
    return 0
}
trap cleanup EXIT
# zsh runs the EXIT trap when the script is hung up, but not when it is
# interrupted or terminated; route those through exit so a Ctrl-C partway
# into the build sweeps like any other ending.
trap 'exit 1' INT TERM HUP

# Flags: --dev builds the local-only "Menubench (Developer)" variant (its own
# bundle id, so it coexists with the official app); --install puts it in /Applications.
DEV=0
INSTALL=0
TEST=0
for arg in "$@"; do
    case "$arg" in
        --dev)     DEV=1 ;;
        --install) INSTALL=1 ;;
        --test)    TEST=1 ;;
    esac
done

if (( DEV )); then
    APP_NAME="Menubench (Developer)"
    EXECUTABLE="MenubenchDeveloper"
    APP_BUNDLE_ID="com.celikugurdev.menubench.dev"
    BUILD_VARIANT_FLAGS=(-D MENUBENCH_DEVELOPMENT)
    APP_OPTIMIZATION_FLAGS=(-Onone)
    BUILD_CONFIGURATION="debug"
else
    APP_NAME="Menubench"
    EXECUTABLE="Menubench"
    APP_BUNDLE_ID="com.celikugurdev.menubench"
    BUILD_VARIANT_FLAGS=()
    APP_OPTIMIZATION_FLAGS=(-O)
    BUILD_CONFIGURATION="release"
fi
FAN_HELPER_ID="$APP_BUNDLE_ID.fan-control"
TARGET="arm64-apple-macosx14.0"
ENTITLEMENTS="Resources/Menubench.entitlements"
LEGACY_IDENTITY="Menubench Local Signing"
MARKETING_VERSION="1.0.1"
CURRENT_PROJECT_VERSION="2"
MACOSX_DEPLOYMENT_TARGET="14.0"

developer_id_identity() {
    security find-identity -v -p codesigning 2>/dev/null \
        | grep 'Developer ID Application' \
        | head -1 \
        | sed -E 's/.*"(.*)".*/\1/' || true
}

# The Developer build exists for iterative local work, where an ad-hoc
# signature is a trap: macOS ties Accessibility and Screen Recording grants to
# the exact binary hash, so every rebuild orphans them while System Settings
# keeps showing them as granted, and no new prompt ever appears. When no
# identity is installed, create the stable local one up front instead of
# falling through to ad-hoc — setup-signing.sh is free, offline and idempotent.
if (( DEV )) && [[ -z "$(developer_id_identity)" ]] \
    && ! security find-identity -p codesigning 2>/dev/null | grep -q "$LEGACY_IDENTITY"; then
    echo "▸ No signing identity installed; creating the stable local one…"
    if ! ./Tools/setup-signing.sh; then
        echo "  ⚠ Tools/setup-signing.sh failed; signing ad-hoc instead." >&2
        echo "    Accessibility and Screen Recording grants will not survive rebuilds:" >&2
        echo "    System Settings will show them as granted while the app is not trusted." >&2
        echo "    After fixing the identity, clear the stale grant once with:" >&2
        echo "      tccutil reset Accessibility $APP_BUNDLE_ID" >&2
    fi
fi

codesign_with_timestamp_retry() {
    local attempt
    for attempt in 1 2 3; do
        if /usr/bin/codesign "$@"; then
            return 0
        fi
        if (( attempt < 3 )); then
            echo "  Developer ID signing failed; retrying ($((attempt + 1))/3)"
            sleep "$attempt"
        fi
    done
    return 1
}

write_swift_output_file_map() {
    local output_file="$1"
    local object_dir="$2"
    shift 2
    local source artifact

    {
        print -r -- "{"
        print -r -- "  \"\": {"
        print -r -- "    \"swift-dependencies\": \"$object_dir/master.swiftdeps\""
        print -r -- "  }"
        for source in "$@"; do
            artifact="${source//\//__}"
            artifact="${artifact%.swift}"
            print -r -- ","
            print -r -- "  \"$source\": {"
            print -r -- "    \"object\": \"$object_dir/$artifact.o\","
            print -r -- "    \"swift-dependencies\": \"$object_dir/$artifact.swiftdeps\""
            print -r -- "  }"
        done
        print -r -- "}"
    } > "$output_file"
}

finalize_installed_bundle_after_child() {
    local bundle="$1"
    local helper="$bundle/Contents/Library/LaunchServices/$FAN_HELPER_ID"
    local devid
    devid="$(developer_id_identity)"

    echo "▸ Finalizing installed signature…"
    sleep 3
    if [[ -n "$devid" ]]; then
        [[ -f "$helper" ]] && codesign_with_timestamp_retry --force --strip-disallowed-xattrs \
            --options runtime --timestamp --identifier "$FAN_HELPER_ID" --sign "$devid" "$helper"
        codesign_with_timestamp_retry --force --strip-disallowed-xattrs --options runtime --timestamp \
            --entitlements "$ENTITLEMENTS" --sign "$devid" "$bundle"
    elif security find-identity -p codesigning 2>/dev/null | grep -q "$LEGACY_IDENTITY"; then
        [[ -f "$helper" ]] && /usr/bin/codesign --force --strip-disallowed-xattrs \
            --identifier "$FAN_HELPER_ID" --sign "$LEGACY_IDENTITY" "$helper"
        /usr/bin/codesign --force --strip-disallowed-xattrs --sign "$LEGACY_IDENTITY" "$bundle"
    else
        [[ -f "$helper" ]] && /usr/bin/codesign --force --strip-disallowed-xattrs \
            --identifier "$FAN_HELPER_ID" --sign - "$helper"
        /usr/bin/codesign --force --strip-disallowed-xattrs --sign - "$bundle"
    fi
    [[ -f "$helper" ]] && /usr/bin/codesign --verify --strict "$helper"
    /usr/bin/codesign --verify --deep --strict "$bundle"
    echo "✓ Signature ready: $bundle"
}

if (( INSTALL && ! TEST )) && [[ "${MENUBENCH_INSTALL_CHILD:-0}" != "1" ]]; then
    MENUBENCH_INSTALL_CHILD=1 "$0" "$@"
    child_status=$?
    if (( child_status != 0 )); then
        exit "$child_status"
    fi
    finalize_installed_bundle_after_child "/Applications/$APP_NAME.app"
    exit 0
fi

# A full Xcode installation carries a matched compiler and SDK. Prefer it over a
# separately updated Command Line Tools installation when both are available.
if [[ -z "${DEVELOPER_DIR:-}" && -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

# Fall back to the macOS 26 SDK when only Command Line Tools are available: the
# 27 SDK turns SwiftUI property wrappers into macros that CLT cannot load yet.
PINNED_SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk"
if [[ -n "${DEVELOPER_DIR:-}" ]]; then
    SDK="$(xcrun --show-sdk-path)"
elif [[ -d "$PINNED_SDK" ]]; then
    SDK="$PINNED_SDK"
else
    SDK="$(xcrun --show-sdk-path)"
fi
SDK_COMPAT_FLAGS=()
VM_STATISTICS_COMPAT_FLAGS=(-I Sources/VMStatisticsCompat)
if [[ "$SDK" == "$PINNED_SDK" ]]; then
    # Swift 6.4 can read the SDK 26 interfaces when given their compiler version.
    SDK_COMPAT_FLAGS=(-Xfrontend -interface-compiler-version -Xfrontend 6.3.2)
fi

# The defaults migrations under test need a real UserDefaults suite, and every
# suite leaves an empty plist in ~/Library/Preferences. The tests already clear
# the domains, but cfprefsd writes the emptied file back out around the time the
# process that owned it exits, so only a caller that outlives the run can remove
# them. `MetricsTests` keeps every suite name inside these two namespaces (a
# check in the test file holds it to that), which is what makes this sweep
# complete rather than a list to keep in step by hand.
discard_test_preferences() {
    local preferences="$HOME/Library/Preferences" name
    for name in "menubench.tests." "com.celikugurdev.menubench.tests."; do
        rm -f "$preferences"/$name*.plist(N)
    done
    rm -f "$preferences/metrics-tests.plist"
    local survivors
    survivors=$(find "$preferences" -maxdepth 1 \
        \( -name "menubench.tests.*.plist" -o -name "com.celikugurdev.menubench.tests.*.plist" \
           -o -name "metrics-tests.plist" \) 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$survivors" != "0" ]]; then
        echo "✗ the test run left $survivors preference file(s) in $preferences" >&2
        return 1
    fi
}

# --test: compile and run the standalone unit tests (pure helpers only: metrics,
# Homebrew parsing, defaults, localization contracts; no app, no UI, no IOKit),
# then exit. Fast and deterministic; no XCTest needed.
if (( TEST )); then
    echo "▸ Building & running unit tests against $(basename "$SDK")…"
    rm -rf build
    mkdir -p build
    # The full app build below remains optimized and is the optimizer gate.
    # Unit assertions do not need optimization; avoiding it cuts most of the
    # test harness compile time without reducing the code the tests exercise.
    swiftc -Onone -target "$TARGET" -sdk "$SDK" "${SDK_COMPAT_FLAGS[@]}" \
        "${VM_STATISTICS_COMPAT_FLAGS[@]}" \
        Sources/Menubench/Services/Media/MediaDownloadSupport.swift \
        Sources/Menubench/Services/Media/MediaSupport.swift \
        Sources/Menubench/Core/Defaults.swift \
        Sources/Menubench/Core/FeatureCatalog.swift \
        Sources/Menubench/Core/FeaturePresets.swift \
        Sources/Menubench/Core/FeatureHubStrings.swift \
        Sources/Menubench/Core/ShortcutSettingsStrings.swift \
        Sources/Menubench/Core/SettingsBackupSupport.swift \
        Sources/Menubench/Core/BackupStrings.swift \
        Sources/Menubench/Core/SnippetStrings.swift \
        Sources/Menubench/Core/BrightnessStrings.swift \
        Sources/Menubench/Core/MediaImageStrings.swift \
        Sources/Menubench/Core/QuickToggleStrings.swift \
        Sources/Menubench/Core/ScreenshotStrings.swift \
        Sources/Menubench/Core/RecentCaptureStrings.swift \
        Sources/Menubench/Core/RecorderStrings.swift \
        Sources/Menubench/Core/RecorderShareStrings.swift \
        Sources/Menubench/Core/CameraPreviewStrings.swift \
        Sources/Menubench/Core/ScratchpadStrings.swift \
        Sources/Menubench/Core/FinderRenameStrings.swift \
        Sources/Menubench/Core/CommandBarStrings.swift \
        Sources/Menubench/Core/FeedbackStrings.swift \
        Sources/Menubench/Core/RadialMenuStrings.swift \
        Sources/Menubench/Core/MenuBarAppearanceStrings.swift \
        Sources/Menubench/Core/AppAppearance.swift \
        Sources/Menubench/Core/AppearanceStrings.swift \
        Sources/Menubench/Core/BatteryTimeStrings.swift \
        Sources/Menubench/Core/KeepAwakeStrings.swift \
        Sources/Menubench/Core/BluetoothSleepStrings.swift \
        Sources/Menubench/Core/PermissionGuideStrings.swift \
        Sources/Menubench/Core/FanControlStrings.swift \
        Sources/Menubench/Services/FanControl/FanControlSupport.swift \
        Sources/Menubench/Services/Snippets/TextSnippetSupport.swift \
        Sources/Menubench/Services/RadialMenu/RadialMenuSupport.swift \
        Sources/Menubench/Services/QuickTools/ScratchpadSupport.swift \
        Sources/Menubench/Services/KillProcess/KillProcessSupport.swift \
        Sources/Menubench/Services/Recorder/RecorderSupport.swift \
        Sources/Menubench/Services/Recorder/RecordingSharingSupport.swift \
        Sources/Menubench/Services/PrivateFileStore.swift \
        Sources/Menubench/Services/Recorder/RecorderTakeStore.swift \
        Sources/Menubench/Services/Recorder/RecorderMotion.swift \
        Sources/Menubench/Services/Recorder/RecorderPointerTrack.swift \
        Sources/Menubench/Services/Recorder/RecorderTypingTrack.swift \
        Sources/Menubench/Services/Recorder/RecorderTimeline.swift \
        Sources/Menubench/Services/Recorder/RecorderTextOverlay.swift \
        Sources/Menubench/Services/Recorder/RecorderEditDocument.swift \
        Sources/Menubench/Core/AppInfo.swift \
        Sources/Menubench/Core/GlobalShortcut.swift \
        Sources/Menubench/Core/Localization.swift \
        Sources/Menubench/Core/Localizations/Strings+*.swift \
        Sources/Menubench/Core/FeatureStrings.swift \
        Sources/Menubench/Core/KillProcessStrings.swift \
        Sources/Menubench/Core/WhatsAppDownloadStrings.swift \
        Sources/Menubench/Core/WhatsAppOrganizerStrings.swift \
        Sources/Menubench/Core/ReleaseNotes.swift \
        Sources/Menubench/Core/URLCleaning.swift \
        Sources/Menubench/Services/GeneralPasteboardAccess.swift \
        Sources/Menubench/Services/Audio/MixerRoutingSupport.swift \
        Sources/Menubench/Services/Audio/MusicLaunchSupport.swift \
        Sources/Menubench/Services/Bluetooth/BluetoothSleepSupport.swift \
        Sources/Menubench/UI/MenuPanel/MixerPercentNativeTextField.swift \
        Sources/Menubench/Services/Audio/BoostLimiter.swift \
        Sources/Menubench/Services/Audio/MixerRender.swift \
        Sources/Menubench/Services/Audio/PreciseVolumeRollerSupport.swift \
        Sources/Menubench/Services/DockPreview/DockPreviewSupport.swift \
        Sources/Menubench/Services/Homebrew/HomebrewSupport.swift \
        Sources/Menubench/Services/AppUpdates/AppUpdatesSupport.swift \
        Sources/Menubench/Core/AppUpdateStrings.swift \
        Sources/Menubench/Core/DiskImageInstallerStrings.swift \
        Sources/Menubench/Services/DiskImageInstaller/DiskImageInstallerSupport.swift \
        Sources/Menubench/Services/Clipboard/ClipboardHistorySupport.swift \
        Sources/Menubench/Services/Clipboard/ClipboardAutoClearSupport.swift \
        Sources/Menubench/Services/AutoQuit/AutoQuitSupport.swift \
        Sources/Menubench/Services/Shelf/ShelfSupport.swift \
        Sources/Menubench/Services/Finder/FinderRenameSupport.swift \
        Sources/Menubench/Services/Update/UpdateInstallerSupport.swift \
        Sources/Menubench/Services/Update/UpdateServiceSupport.swift \
        Sources/Menubench/Services/InstalledApps.swift \
        Sources/Menubench/Services/LaunchAtLoginSupport.swift \
        Sources/Menubench/UI/Settings/SettingsSearchSupport.swift \
        Sources/Menubench/UI/Settings/FeatureVisibilitySupport.swift \
        Sources/Menubench/App/MenuBarSpacingSupport.swift \
        Sources/Menubench/App/StatusItemAnchorSupport.swift \
        Sources/Menubench/Services/DockClick/DockClickSupport.swift \
        Sources/Menubench/Services/Finder/CutPasteProgressSupport.swift \
        Sources/Menubench/Services/Finder/FinderPasteImageSupport.swift \
        Sources/Menubench/Services/MiddleClick/MiddleClickSupport.swift \
        Sources/Menubench/Services/MouseNavigation/MouseNavigationSupport.swift \
        Sources/Menubench/Services/MouseButtons/MouseButtonShortcutSupport.swift \
        Sources/Menubench/Services/MouseButtons/MouseSpacesGestureSupport.swift \
        Sources/Menubench/Services/MouseExceptions/MouseAppExceptionSupport.swift \
        Sources/Menubench/Core/MouseButtonStrings.swift \
        Sources/Menubench/Core/MouseExceptionStrings.swift \
        Sources/Menubench/Core/ClipboardIgnoredAppsStrings.swift \
        Sources/Menubench/Core/WindowPreviewExclusionStrings.swift \
        Sources/Menubench/Core/DiskExclusionStrings.swift \
        Sources/Menubench/Core/SwitcherAppRulesStrings.swift \
        Sources/Menubench/Services/QuickTools/QuickToolsSupport.swift \
        Sources/Menubench/Services/CommandBar/CommandBarSupport.swift \
        Sources/Menubench/Services/CommandBar/CommandBarPreferences.swift \
        Sources/Menubench/Services/CommandBar/CommandBarMath.swift \
        Sources/Menubench/Services/CommandBar/CommandBarUnits.swift \
        Sources/Menubench/Services/CommandBar/CommandBarEmoji.swift \
        Sources/Menubench/Services/CommandBar/CommandBarLinks.swift \
        Sources/Menubench/Services/CommandBar/CommandBarDates.swift \
        Sources/Menubench/Services/CommandBar/CommandBarRowShortcuts.swift \
        Sources/Menubench/Services/CommandBar/CommandBarSystemSettingsSupport.swift \
        Sources/Menubench/Services/CommandBar/CommandBarFileSearchSupport.swift \
        Sources/Menubench/Services/CommandBar/CommandBarQueryMemory.swift \
        Sources/Menubench/Services/SpotlightNamesSupport.swift \
        Sources/Menubench/Services/QuickTools/MicMuteSupport.swift \
        Sources/Menubench/Services/QuickTools/QuickTogglesSupport.swift \
        Sources/Menubench/Services/QuickTools/ScreenshotCapturePolicy.swift \
        Sources/Menubench/Services/QuickTools/ScreenshotSupport.swift \
        Sources/Menubench/Services/QuickTools/ScreenshotSharingSupport.swift \
        Sources/Menubench/Services/QuickTools/WindowActivationPolicy.swift \
        Sources/Menubench/Services/KeyboardDebounce/KeyboardDebounceSupport.swift \
        Sources/Menubench/Services/SuperKey/SuperKeySupport.swift \
        Sources/Menubench/Services/SuperKey/SuperKeyMappingGuard.swift \
        Sources/Menubench/Core/SuperKeyStrings.swift \
        Sources/Menubench/Services/SessionActivity.swift \
        Sources/Menubench/Services/SessionActivitySupport.swift \
        Sources/Menubench/Services/ScrollWheelSupport.swift \
        Sources/Menubench/Services/SmoothScrollSupport.swift \
        Sources/Menubench/Services/FocusFollowsMouse/FocusFollowsMouseSupport.swift \
        Sources/Menubench/Services/Switcher/SwitcherModels.swift \
        Sources/Menubench/Services/Switcher/SwitcherSupport.swift \
        Sources/Menubench/Services/Switcher/SpaceHopSupport.swift \
        Sources/Menubench/Services/Switcher/WindowUseOrder.swift \
        Sources/Menubench/Services/Metrics/MetricFormat.swift \
        Sources/Menubench/Services/Metrics/NetworkQualitySupport.swift \
        Sources/Menubench/Services/Metrics/VMStatisticsDecoder.swift \
        Sources/Menubench/Services/KeepAwakeAutomationSupport.swift \
        Sources/Menubench/Services/SudoersSupport.swift \
        Sources/Menubench/Services/Metrics/BatteryTimeSupport.swift \
        Sources/Menubench/Services/BoundedProcessRunner.swift \
        Sources/Menubench/Services/DetachedProcess.swift \
        Sources/Menubench/Services/ShellSupport.swift \
        Sources/Menubench/Services/Metrics/NetworkProcessSupport.swift \
        Sources/Menubench/Services/Metrics/NetworkSampler.swift \
        Sources/Menubench/Services/Metrics/PeripheralBatterySupport.swift \
        Sources/Menubench/Services/Metrics/DiskSupport.swift \
        Sources/Menubench/Services/Metrics/MonitorSamplingPolicy.swift \
        Sources/Menubench/Services/Metrics/MaxCapacityProbe.swift \
        Sources/Menubench/Services/Metrics/TemperatureSensorSelector.swift \
        Sources/Menubench/Services/Metrics/SustainedAlertGate.swift \
        Sources/Menubench/Services/WindowLayout/WindowLayoutSupport.swift \
        Sources/Menubench/Services/WindowLayout/WindowGestureSupport.swift \
        Sources/Menubench/Core/WindowDirectionalStrings.swift \
        Sources/Menubench/Services/CleaningMode/CleaningUnlockCounter.swift \
        Sources/Menubench/Services/Display/ExtraBrightnessSupport.swift \
        Sources/Menubench/Services/Display/BrightnessSupport.swift \
        Sources/Menubench/Services/Cleaner/CleanerSupport.swift \
        Sources/Menubench/Services/Cleaner/CleanerPolicy.swift \
        Sources/Menubench/Services/Cleaner/CleanerSchedule.swift \
        Sources/Menubench/Services/Uninstall/UninstallerSupport.swift \
        Sources/Menubench/Services/ManagedDownloads/WhatsAppDownloadSupport.swift \
        Tests/MetricsTests.swift \
        -o build/metrics-tests
    # `set -e` would end the script on a failing run before the sweep below.
    test_status=0
    ./build/metrics-tests || test_status=$?
    discard_test_preferences || test_status=1
    exit $test_status
fi

echo "▸ Compiling ($BUILD_CONFIGURATION) against $(basename "$SDK")…"
APP_SOURCES=(Sources/Menubench/**/*.swift)
if (( DEV )); then
    APP_OBJECT_DIR="build/objects/$EXECUTABLE"
    mkdir -p build "$APP_OBJECT_DIR"
    APP_OUTPUT_FILE_MAP="$APP_OBJECT_DIR/output-file-map.json"
    write_swift_output_file_map "$APP_OUTPUT_FILE_MAP" "$APP_OBJECT_DIR" "${APP_SOURCES[@]}"
    BUILD_JOBS="$(sysctl -n hw.logicalcpu 2>/dev/null || true)"
    [[ "$BUILD_JOBS" == <-> ]] || BUILD_JOBS=4
    swiftc "${APP_OPTIMIZATION_FLAGS[@]}" -incremental -j "$BUILD_JOBS" \
        -output-file-map "$APP_OUTPUT_FILE_MAP" \
        -target "$TARGET" -sdk "$SDK" "${SDK_COMPAT_FLAGS[@]}" "${VM_STATISTICS_COMPAT_FLAGS[@]}" \
        "${BUILD_VARIANT_FLAGS[@]}" \
        "${APP_SOURCES[@]}" -o "build/$EXECUTABLE"
else
    rm -rf build
    mkdir -p build
    swiftc "${APP_OPTIMIZATION_FLAGS[@]}" -target "$TARGET" -sdk "$SDK" \
        "${SDK_COMPAT_FLAGS[@]}" "${VM_STATISTICS_COMPAT_FLAGS[@]}" "${BUILD_VARIANT_FLAGS[@]}" \
        "${APP_SOURCES[@]}" -o "build/$EXECUTABLE"
fi

echo "▸ Compiling protected fan helper…"
swiftc -O -target "$TARGET" -sdk "$SDK" "${SDK_COMPAT_FLAGS[@]}" "${BUILD_VARIANT_FLAGS[@]}" \
    Sources/Menubench/Services/FanControl/FanControlSupport.swift \
    Sources/Menubench/Services/FanControl/FanControlXPC.swift \
    Sources/Menubench/Services/SystemMonitor/SMCClient.swift \
    Sources/Menubench/Services/Metrics/TemperatureSensorSelector.swift \
    Sources/Menubench/Services/FanControl/FanControlHardware.swift \
    Sources/FanControlHelper/main.swift \
    -o "build/$FAN_HELPER_ID"
"build/$FAN_HELPER_ID" --selftest

echo "▸ Generating app icon…"
swift Tools/MakeIcon.swift build/AppIcon.iconset
xattr -c -r build/AppIcon.iconset build/AppIcon.icns build/MenuBarIcon.png build/MenuBarIcon@2x.png build/BrandMark.png 2>/dev/null || true
ACTOOL_BIN="$(xcrun --find actool 2>/dev/null || true)"
ICON_TMP="$(mktemp -d)"
ADAPTIVE_SKIP=""
if [[ -z "$ACTOOL_BIN" ]]; then
    ADAPTIVE_SKIP="actool not found (adaptive icons need Xcode 26+)"
else
    echo "▸ Compiling adaptive icon catalog…"
    # actool crashes on File Provider-synced paths, so compile a local copy.
    ditto "Resources/Brand/MenubenchAppIcon.icon" "$ICON_TMP/AppIcon.icon"
    # Xcode 27 beta actool requires the --compile target directory to already exist.
    mkdir -p "$ICON_TMP/catalog"
    if "$ACTOOL_BIN" "$ICON_TMP/AppIcon.icon" \
            --compile "$ICON_TMP/catalog" \
            --app-icon AppIcon \
            --platform macosx \
            --target-device mac \
            --minimum-deployment-target 14.0 \
            --enable-on-demand-resources NO \
            --output-partial-info-plist "$ICON_TMP/partial-info.plist" \
            >"$ICON_TMP/actool.log" 2>&1 && [[ -s "$ICON_TMP/catalog/Assets.car" ]]; then
        mv "$ICON_TMP/catalog/Assets.car" build/Assets.car
    else
        ADAPTIVE_SKIP="actool could not compile the catalog"
    fi
fi
if [[ -n "$ADAPTIVE_SKIP" ]]; then
    cp "$ICON_TMP/actool.log" build/actool-failure.log 2>/dev/null || true
    echo "  adaptive icon skipped: $ADAPTIVE_SKIP (Dock falls back to AppIcon.icns)"
fi
echo "▸ Assembling and signing bundle…"
STAGE_TMP="$(mktemp -d)"
STAGE="$STAGE_TMP/$APP_NAME.app"
mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources" \
    "$STAGE/Contents/Library/LaunchDaemons" "$STAGE/Contents/Library/LaunchServices"
cp "build/$EXECUTABLE" "$STAGE/Contents/MacOS/$EXECUTABLE"
cp "build/$FAN_HELPER_ID" "$STAGE/Contents/Library/LaunchServices/$FAN_HELPER_ID"
cp Resources/com.celikugurdev.menubench.fan-control.plist \
    "$STAGE/Contents/Library/LaunchDaemons/$FAN_HELPER_ID.plist"
cp Resources/Info.plist "$STAGE/Contents/Info.plist"
cp CHANGELOG.md "$STAGE/Contents/Resources/CHANGELOG.md"
for lproj in Resources/*.lproj(N); do
    cp -R "$lproj" "$STAGE/Contents/Resources/"
done
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $APP_BUNDLE_ID" "$STAGE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $MARKETING_VERSION" "$STAGE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $CURRENT_PROJECT_VERSION" "$STAGE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :LSMinimumSystemVersion $MACOSX_DEPLOYMENT_TARGET" "$STAGE/Contents/Info.plist"
if (( DEV )); then
    # A distinct identity so the Developer build installs and runs next to the
    # official app, with its own permissions, preferences and login item.
    /usr/libexec/PlistBuddy -c "Set :CFBundleName Menubench (Developer)" "$STAGE/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Menubench (Developer)" "$STAGE/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $EXECUTABLE" "$STAGE/Contents/Info.plist"
    FAN_PLIST="$STAGE/Contents/Library/LaunchDaemons/$FAN_HELPER_ID.plist"
    /usr/libexec/PlistBuddy -c "Set :Label $FAN_HELPER_ID" "$FAN_PLIST"
    /usr/libexec/PlistBuddy -c "Set :BundleProgram Contents/Library/LaunchServices/$FAN_HELPER_ID" "$FAN_PLIST"
    /usr/libexec/PlistBuddy -c "Delete :MachServices:com.celikugurdev.menubench.fan-control" "$FAN_PLIST"
    /usr/libexec/PlistBuddy -c "Add :MachServices:$FAN_HELPER_ID bool true" "$FAN_PLIST"
    # Stamp the source commit + build time so the running dev app shows (in About)
    # exactly which code it was compiled from. Lets you verify it matches HEAD before
    # testing, instead of unknowingly running a stale build. Dev-only; never shipped.
    SHA="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
    [[ -n "$(git status --porcelain 2>/dev/null)" ]] && SHA="$SHA-dirty"
    /usr/libexec/PlistBuddy -c "Add :MenubenchBuildCommit string '$SHA · $(date '+%Y-%m-%d %H:%M')'" "$STAGE/Contents/Info.plist"
    echo "  stamped dev build: $SHA"
fi
FAN_HELPER_VERSION="$(
    export LC_ALL=C
    /usr/bin/shasum -a 256 \
        "$STAGE/Contents/Library/LaunchServices/$FAN_HELPER_ID" \
        "$STAGE/Contents/Library/LaunchDaemons/$FAN_HELPER_ID.plist" \
        | /usr/bin/awk '{print $1}' | /usr/bin/shasum -a 256 \
        | /usr/bin/awk '{print $1}'
)"
/usr/libexec/PlistBuddy -c "Add :MenubenchFanControlHelperVersion string '$FAN_HELPER_VERSION'" \
    "$STAGE/Contents/Info.plist"
printf 'APPL????' > "$STAGE/Contents/PkgInfo"
cp build/AppIcon.icns "$STAGE/Contents/Resources/AppIcon.icns"
cp build/MenuBarIcon.png build/MenuBarIcon@2x.png build/BrandMark.png "$STAGE/Contents/Resources/"
cp Resources/Brand/MenubenchAppIcon.png "$STAGE/Contents/Resources/MenubenchAppIcon.png"
if [[ -f build/Assets.car ]]; then
    cp build/Assets.car "$STAGE/Contents/Resources/Assets.car"
fi
if [[ -d Resources/Gifs ]]; then
    mkdir -p "$STAGE/Contents/Resources/Gifs"
    cp Resources/Gifs/*.gif "$STAGE/Contents/Resources/Gifs/"
fi
if [[ -d Resources/Images ]]; then
    mkdir -p "$STAGE/Contents/Resources/Images"
    cp Resources/Images/* "$STAGE/Contents/Resources/Images/"
fi
xattr -c -r "$STAGE" 2>/dev/null || true

# Signing, in order of preference:
#   1. Developer ID Application — the real, Apple-issued identity used for
#      notarized releases. Signed with the hardened runtime (required for
#      notarization), the app's entitlements and a secure timestamp. Gives a
#      stable, team-based designated requirement, so permissions persist across
#      updates AND Gatekeeper shows no "unverified developer" warning.
#   2. "Menubench Local Signing" — the stable self-signed local identity
#      as a fallback so contributors without a Developer ID still get a constant
#      designated requirement across their local builds.
#   3. Ad-hoc — fresh clone with no identity at all.
DEVID="$(developer_id_identity)"
codesign_app() {
    local target="$1"
    if [[ -n "$DEVID" ]]; then
        codesign_with_timestamp_retry --force --strip-disallowed-xattrs --options runtime --timestamp \
            --entitlements "$ENTITLEMENTS" --sign "$DEVID" "$target"
    elif security find-identity -p codesigning 2>/dev/null | grep -q "$LEGACY_IDENTITY"; then
        codesign --force --strip-disallowed-xattrs --sign "$LEGACY_IDENTITY" "$target"
    else
        codesign --force --strip-disallowed-xattrs --sign - "$target"
    fi
}

codesign_fan_helper() {
    local target="$1"
    if [[ -n "$DEVID" ]]; then
        codesign_with_timestamp_retry --force --strip-disallowed-xattrs --options runtime --timestamp \
            --identifier "$FAN_HELPER_ID" --sign "$DEVID" "$target"
    elif security find-identity -p codesigning 2>/dev/null | grep -q "$LEGACY_IDENTITY"; then
        codesign --force --strip-disallowed-xattrs --identifier "$FAN_HELPER_ID" \
            --sign "$LEGACY_IDENTITY" "$target"
    else
        codesign --force --strip-disallowed-xattrs --identifier "$FAN_HELPER_ID" --sign - "$target"
    fi
}

sign_bundle() {
    local bundle="$1"
    local executable="$bundle/Contents/MacOS/$EXECUTABLE"
    local helper="$bundle/Contents/Library/LaunchServices/$FAN_HELPER_ID"

    if [[ -n "$DEVID" ]]; then
        echo "  signing with Developer ID (hardened runtime): $DEVID"
    elif security find-identity -p codesigning 2>/dev/null | grep -q "$LEGACY_IDENTITY"; then
        echo "  signing with legacy self-signed identity: $LEGACY_IDENTITY"
    else
        echo "  signing ad-hoc (no identity installed — run Tools/setup-signing.sh)"
    fi
    [[ -f "$helper" ]] && codesign_fan_helper "$helper"
    codesign_app "$bundle"

    # If local filesystem metadata invalidates the first signature, sign once
    # more. The installed Developer bundle is signed again after the final copy.
    if ! codesign --verify --deep --strict "$bundle" >/dev/null 2>&1; then
        echo "  re-signing after filesystem metadata settled"
        xattr -c -r "$bundle" 2>/dev/null || true
        [[ -f "$helper" ]] && codesign_fan_helper "$helper"
        codesign_app "$bundle"
    fi
    [[ -f "$executable" ]] && codesign --verify --strict "$executable"
    [[ -f "$helper" ]] && codesign --verify --strict "$helper"
    codesign --verify --deep --strict "$bundle"
}

sign_installed_bundle() {
    local bundle="$1"
    wait_for_install_metadata "$bundle"
    sign_bundle "$bundle"
}

sign_bundle "$STAGE"

process_is_running() {
    local proc="$1"
    if (( ${#proc} > 15 )); then
        pgrep -f "/Contents/MacOS/$proc" >/dev/null 2>&1
    else
        pgrep -x "$proc" >/dev/null 2>&1
    fi
}

stop_process() {
    local proc="$1"
    if (( ${#proc} > 15 )); then
        pkill -f "/Contents/MacOS/$proc" 2>/dev/null || true
    else
        pkill -x "$proc" 2>/dev/null || true
    fi
    for _ in {1..50}; do
        if ! process_is_running "$proc"; then
            return 0
        fi
        sleep 0.1
    done
    echo "✗ $proc is still running — quit it and retry" >&2
    return 1
}

wait_for_install_metadata() {
    local bundle="$1"
    local missing
    for _ in {1..50}; do
        missing=0
        while IFS= read -r file; do
            if ! xattr -p com.apple.provenance "$file" >/dev/null 2>&1; then
                missing=1
                break
            fi
        done < <(find "$bundle/Contents" -type f ! -path "*/_CodeSignature/*")
        if (( missing == 0 )); then
            return 0
        fi
        sleep 0.1
    done
}

mkdir -p "build/stage"
BUILD_STAGE="build/stage/$APP_NAME.app"
rm -rf "$BUILD_STAGE"
ditto --noextattr --noqtn "$STAGE" "$BUILD_STAGE"
xattr -c -r "$BUILD_STAGE" 2>/dev/null || true
if ! codesign --verify --deep --strict "$BUILD_STAGE" >/dev/null 2>&1; then
    if xattr -lr "$BUILD_STAGE" 2>/dev/null | grep -Eq 'com\.apple\.(FinderInfo|ResourceFork|provenance|fileprovider)'; then
        echo "  build/stage copy has local filesystem metadata; temp bundle was verified"
    else
        codesign --verify --deep --strict "$BUILD_STAGE"
    fi
fi
echo "✓ Bundle ready: $BUILD_STAGE"

if (( INSTALL )); then
    echo "▸ Installing into /Applications…"
    stop_process "$EXECUTABLE"
    INSTALL_DEST="/Applications/$APP_NAME.app"
    rm -rf "$INSTALL_DEST"
    ditto --noextattr --noqtn "$STAGE" "$INSTALL_DEST"
    sign_installed_bundle "$INSTALL_DEST"
    echo "✓ Installed: $INSTALL_DEST"
fi
