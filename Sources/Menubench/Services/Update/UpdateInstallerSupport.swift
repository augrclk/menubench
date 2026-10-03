// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Pure helpers for the self-update installer: the shell script text, the
/// quoting for its elevated (admin) variant and the parsing of the result
/// marker the script leaves behind. No AppKit, so the unit tests cover the
/// quoting and the script's failure-reporting contract.
enum UpdateInstallerSupport {
    /// Marker the script writes before each fallible step (write-ahead, so
    /// the marker names the failing step even if the script dies mid-way)
    /// and replaces with "ok" once the new bundle is in place.
    static func installFailureCode(fromMarker marker: String) -> String? {
        let trimmed = marker.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("fail") else { return nil }
        return trimmed
    }

    /// Captures a bounded regular file through one descriptor. In particular,
    /// a swapped symlink/FIFO cannot make root copy a different path or block.
    /// The captured bytes are verified only AFTER the copy, in a private directory.
    static let snapshotCopyProgram = #"""
    use strict; use warnings; use Fcntl qw(:DEFAULT :mode);
    my ($source, $destination, $limit) = @ARGV;
    sysopen(my $input, $source, O_RDONLY | O_NOFOLLOW | O_NONBLOCK) or die "open source: $!";
    my @info = stat($input);
    @info && S_ISREG($info[2]) && $info[7] > 0 && $info[7] <= $limit or die "invalid source";
    sysopen(my $output, $destination, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0600)
        or die "open snapshot: $!";
    my $total = 0;
    while (1) {
        my $count = sysread($input, my $buffer, 65536);
        defined($count) or die "read: $!";
        last unless $count;
        $total += $count;
        $total <= $limit or die "download too large";
        my $offset = 0;
        while ($offset < $count) {
            my $written = syswrite($output, $buffer, $count - $offset, $offset);
            defined($written) && $written > 0 or die "write: $!";
            $offset += $written;
        }
    }
    $total == $info[7] or die "source changed size";
    close($output) or die "close: $!";
    """#

    /// rename(2) treats its destination as an exact leaf. Unlike mv, it never
    /// moves the bundle INTO a directory/symlink that appeared at the destination.
    static let renameProgram = #"""
    use strict; use warnings;
    rename($ARGV[0], $ARGV[1]) or die "rename: $!";
    """#

    static func permitsElevatedInstall(appPath: String) -> Bool {
        appPath == "/Applications/Menubench.app"
    }

    /// Arguments: app path, downloaded DMG path, pid, result marker, user uid,
    /// expected release version, Team ID captured from the running signed app.
    static func installerScript() -> String {
        let copy = shellSingleQuoted(snapshotCopyProgram)
        let rename = shellSingleQuoted(renameProgram)
        return """
        #!/bin/sh
        umask 077
        PATH=/usr/bin:/bin:/usr/sbin:/sbin
        export PATH
        APP="$1"; DMG="$2"; PID="$3"; RESULT="$4"; ASUSER="$5"; EXPECTED_VERSION="$6"; EXPECTED_TEAM="$7"
        SCRIPT="$0"
        WORK=""; MNT=""; BACKUP=""; LAUNCH="$APP"; RELAUNCH=0
        running_as_root() { [ "$(/usr/bin/id -u)" = "0" ]; }
        # Never let caller-controlled numeric arguments become command options.
        case "$ASUSER" in ''|0|*[!0-9]*) exit 1;; esac
        case "$PID" in ''|0|*[!0-9]*) exit 1;; esac
        [ "${#EXPECTED_TEAM}" = 10 ] || exit 1
        case "$EXPECTED_TEAM" in *[!A-Z0-9]*) exit 1;; esac
        note() {
            if running_as_root; then
                /usr/bin/sudo -n -u "#$ASUSER" /bin/sh -c \
                    '/bin/echo "$1" > "$2.progress"' marker "$1" "$RESULT" 2>/dev/null
                return
            fi
            /bin/echo "$1" > "$RESULT.progress" 2>/dev/null
        }
        finalize() {
            if running_as_root; then
                /usr/bin/sudo -n -u "#$ASUSER" /bin/mv -f \
                    "$RESULT.progress" "$RESULT" 2>/dev/null
                return
            fi
            /bin/mv -f "$RESULT.progress" "$RESULT" 2>/dev/null
        }
        rename_leaf() { /usr/bin/perl -e \(rename) "$1" "$2"; }
        cleanup() {
            if [ -n "$MNT" ]; then
                /usr/bin/hdiutil detach "$MNT" -quiet 2>/dev/null \
                    || /usr/bin/hdiutil detach "$MNT" -force -quiet 2>/dev/null || true
            fi
            # If rollback could not complete, preserve the previous app for recovery.
            if [ -n "$WORK" ] && [ ! -e "$BACKUP" ] && [ ! -L "$BACKUP" ]; then
                /bin/rm -rf "$WORK"
            fi
            if running_as_root; then
                /usr/bin/sudo -n -u "#$ASUSER" /bin/rm -f "$DMG" 2>/dev/null
            else
                /bin/rm -f "$DMG"
                case "$SCRIPT" in /*) /bin/rm -f "$SCRIPT";; esac
            fi
            finalize
            if [ "$RELAUNCH" = 1 ] && ! kill -0 "$PID" 2>/dev/null \
                && /usr/bin/codesign -v --deep --strict -R="$VERIFY_REQ" "$LAUNCH" 2>/dev/null; then
                if running_as_root; then
                    /bin/launchctl asuser "$ASUSER" /usr/bin/sudo -n -u "#$ASUSER" /usr/bin/open "$LAUNCH"
                else
                    /usr/bin/open "$LAUNCH"
                fi
            fi
        }
        trap cleanup EXIT
        trap 'exit 1' HUP INT TERM
        fail() { note "$1"; exit 1; }
        # Elevated writes are allowed only below the system-controlled
        # /Applications parent, never inside a user-selected directory chain.
        if running_as_root; then
            [ "$APP" = "/Applications/Menubench.app" ] && [ ! -L /Applications ] \
                || fail fail-install-location
            WORK="$(/usr/bin/mktemp -d /private/var/root/menubench-update.XXXXXXXX)" \
                || fail fail-tempdir
        else
            APP_DIR="$(/usr/bin/dirname "$APP")"
            WORK="$(/usr/bin/mktemp -d "$APP_DIR/.menubench-update.XXXXXXXX")" \
                || fail fail-tempdir
        fi
        BACKUP="$WORK/previous.app"
        CAPTURED_DMG="$WORK/release.dmg"
        STAGE="$WORK/Menubench.app"
        MNT="$WORK/mount"
        /bin/mkdir "$MNT" || fail fail-tempdir
        VERIFY_REQ="identifier \\"com.celikugurdev.menubench\\" and anchor apple generic and certificate leaf[subject.OU] = \\"$EXPECTED_TEAM\\""
        DMG_VERIFY_REQ="anchor apple generic and certificate leaf[subject.OU] = \\"$EXPECTED_TEAM\\""
        # The running app's signer is passed in memory, never re-learned from
        # replaceable on-disk metadata while the authorization prompt is visible.
        [ -d "$APP" ] && [ ! -L "$APP" ] || fail fail-verify
        /usr/bin/codesign -v --deep --strict -R="$VERIFY_REQ" "$APP" 2>/dev/null \
            || fail fail-verify
        RELAUNCH=1
        note fail-copy
        /usr/bin/perl -e \(copy) "$DMG" "$CAPTURED_DMG" \(downloadCeilingBytes) \
            || fail fail-copy
        note fail-dmg-verify
        /usr/bin/codesign -v --strict -R="$DMG_VERIFY_REQ" "$CAPTURED_DMG" 2>/dev/null \
            || fail fail-dmg-verify
        note fail-mount
        /usr/bin/hdiutil attach "$CAPTURED_DMG" -readonly -nobrowse -quiet -mountpoint "$MNT" \
            || fail fail-mount
        SRC="$MNT/Menubench.app"
        [ -d "$SRC" ] && [ ! -L "$SRC" ] || fail fail-no-app-in-dmg
        /usr/bin/codesign -v --deep --strict -R="$VERIFY_REQ" "$SRC" 2>/dev/null \
            || fail fail-verify
        note fail-copy
        /usr/bin/ditto "$SRC" "$STAGE" || fail fail-copy
        /usr/bin/xattr -cr "$STAGE" 2>/dev/null
        note fail-version
        BUNDLE_VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$STAGE/Contents/Info.plist" 2>/dev/null)"
        [ "$BUNDLE_VERSION" = "$EXPECTED_VERSION" ] || fail fail-version
        note fail-verify
        if ! /usr/sbin/spctl --status 2>/dev/null | /usr/bin/grep -q disabled; then
            /usr/sbin/spctl -a -t exec "$STAGE" >/dev/null 2>&1 || fail fail-verify
        fi
        /usr/bin/codesign -v --deep --strict -R="$VERIFY_REQ" "$STAGE" 2>/dev/null \
            || fail fail-verify
        # Change ownership while the bundle is still inside root's private
        # directory. -P does not traverse symlinks within a signed bundle.
        if running_as_root; then
            /usr/sbin/chown -R -P "$ASUSER" "$STAGE" || fail fail-copy
        fi
        while kill -0 "$PID" 2>/dev/null; do /bin/sleep 0.3; done
        note fail-swap
        rename_leaf "$APP" "$BACKUP" || fail fail-swap
        # Verify the app actually removed from the destination. A last-moment
        # replacement must never authorize root to delete an unrelated bundle.
        if [ -L "$BACKUP" ] \
            || ! /usr/bin/codesign -v --deep --strict -R="$VERIFY_REQ" "$BACKUP" 2>/dev/null; then
            rename_leaf "$BACKUP" "$APP" || true
            fail fail-swap
        fi
        if ! rename_leaf "$STAGE" "$APP"; then
            rename_leaf "$BACKUP" "$APP" || true
            fail fail-swap
        fi
        /bin/rm -rf "$BACKUP"
        note ok
        cleanup
        trap - EXIT
        """
    }

    /// Single-quotes a string for POSIX sh, closing and reopening the quote
    /// around every embedded single quote (same scheme as
    /// HomebrewSupport.shellQuote, minus its bare-word fast path).
    static func shellSingleQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// The shell command run with admin rights when the app's folder is not
    /// writable by the current user. The whole installer travels inline (no
    /// script file that another process could rewrite before root runs it)
    /// and is started in its own session (`DetachedProcess`) so the prompt
    /// returns immediately and the installer outlives the app it replaces.
    static func elevatedInstallCommand(appPath: String,
                                       dmgPath: String,
                                       pid: Int32,
                                       resultPath: String,
                                       uid: uid_t,
                                       expectedVersion: String,
                                       expectedTeamID: String) -> String {
        let script = shellSingleQuoted(installerScript())
        let args = [appPath, dmgPath, "\(pid)", resultPath, "\(uid)", expectedVersion, expectedTeamID]
            .map(shellSingleQuoted)
            .joined(separator: " ")
        return DetachedProcess.detachedShellCommand(
            quotedArgv: "/bin/sh -c \(script) menubench-installer \(args)")
    }

    /// Whether the next install attempt should go straight through the admin
    /// prompt: a previous run failed at the copy or swap step, which is what
    /// missing write permission looks like from inside the installer. Other
    /// codes (bad mount, failed verification) are not permission problems, so
    /// elevating would just add a password prompt to the same failure.
    static func shouldForceAdminInstall(afterFailureCode code: String?) -> Bool {
        code == "fail-copy" || code == "fail-swap"
    }

    /// Whether a new download fraction crossed into the next whole percent,
    /// so the published state changes ~100 times per download instead of on
    /// every URLSession callback. The first known fraction always counts.
    static func progressStepAdvanced(from current: Double?, to fraction: Double) -> Bool {
        guard let current else { return true }
        return Int(fraction * 100) > Int(current * 100)
    }

    /// Absolute ceiling for an update download. Releases are DMGs of roughly
    /// ten megabytes, so this is far above any real asset and only exists to
    /// stop a response that never ends.
    static let downloadCeilingBytes: Int64 = 200 * 1024 * 1024

    /// How many bytes the download may write before it is abandoned. The
    /// release lists the asset's exact size, so that is the bound whenever it
    /// looks sane; an absent or absurd size falls back to the ceiling.
    static func downloadByteLimit(expectedBytes: Int64?,
                                  ceiling: Int64 = downloadCeilingBytes) -> Int64 {
        guard let expectedBytes, expectedBytes > 0, expectedBytes <= ceiling else {
            return ceiling
        }
        return expectedBytes
    }

    /// Whether a finished download may be handed to the installer. The
    /// signature check still decides what gets installed; this only refuses
    /// bodies that cannot be the asset before they are handed to the installer
    /// and mounted.
    static func downloadIsUsable(status: Int,
                                 receivedBytes: Int64,
                                 expectedBytes: Int64?,
                                 ceiling: Int64 = downloadCeilingBytes) -> Bool {
        guard status == 200, receivedBytes > 0, receivedBytes <= ceiling else { return false }
        guard let expectedBytes, expectedBytes > 0 else { return true }
        return receivedBytes == expectedBytes
    }

    /// True when the app cannot be updated in place at all: running from the
    /// randomized read-only mount Gatekeeper uses for translocated apps, or
    /// from any other read-only volume (the mounted DMG). External writable
    /// volumes are fine, so this asks the file system instead of guessing
    /// from the path.
    static func runsFromImmutableLocation(appPath: String,
                                          volumeIsReadOnly: (String) -> Bool) -> Bool {
        appPath.contains("/AppTranslocation/") || volumeIsReadOnly(appPath)
    }
}
