// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Darwin
import Foundation
import Security

/// Runs production helpers against harmless adversarial inputs. No root,
/// authorization prompts, live app replacement or privileged hardware calls.
enum SecurityRegressionTests {
    static func run(expect: (Bool, String) -> Void) {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("MenubenchSecurityTests-\(UUID().uuidString)")
        do {
            try fm.createDirectory(at: root, withIntermediateDirectories: true)
            defer { try? fm.removeItem(at: root) }

            // Imported settings never transfer execution authority, including
            // when the file explicitly forges the local approval flag.
            let script = root.appendingPathComponent("harmless.sh")
            let marker = root.appendingPathComponent("executed")
            try "#!/bin/sh\n/bin/echo harmless > \"$1\"\n/bin/echo done\n"
                .write(to: script, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
            let trusted = CommandBarLink(name: "test", kind: .script,
                                         destination: script.path, runsWithoutArgument: true,
                                         requiresApproval: false)
            let website = CommandBarLink(name: "site", destination: "https://example.com")
            let envelope: [String: Any] = [
                SettingsBackupSupport.formatVersionKey: SettingsBackupSupport.formatVersion,
                SettingsBackupSupport.settingsKey: [DefaultsKey.commandBarLinks: CommandBarLinks.encode([trusted, website])!],
            ]
            let imported = SettingsBackupSupport.sanitizedSettings(from: envelope)!
            let links = CommandBarLinks.decode(imported[DefaultsKey.commandBarLinks] as? Data)
            expect(links.count == 2 && links[0].requiresApproval && !links[1].requiresApproval,
                   "imported scripts lose execution authority; ordinary links remain usable")
            expect(CommandBarLinks.matchingScriptLink(in: links, query: "test") == nil,
                   "unapproved scripts cannot match a query")
            let runner = CommandBarScriptRunner()
            runner.schedule(link: links[0], argument: marker.path)
            runner.runNow(link: links[0], argument: marker.path)
            RunLoop.main.run(until: Date().addingTimeInterval(0.5))
            expect(!fm.fileExists(atPath: marker.path),
                   "both debounced and immediate execution reject an imported script")
            var approved = links[0]
            approved.requiresApproval = false
            runner.runNow(link: approved, argument: marker.path)
            let deadline = Date().addingTimeInterval(5)
            while !fm.fileExists(atPath: marker.path), Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.02))
            }
            expect(fm.fileExists(atPath: marker.path), "explicitly approved local scripts still execute")
            // Drain the result callback before deleting its local executable.
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            runner.reset()
            let legacy = Data(#"[{"name":"local","kind":"script","destination":"/bin/echo"}]"#.utf8)
            expect(CommandBarLinks.decode(legacy).first?.requiresApproval == false,
                   "existing scripts saved locally before the flag remain usable")
            let legacyImport = SettingsBackupSupport.sanitizedSettings(from: [
                SettingsBackupSupport.formatVersionKey: 1,
                SettingsBackupSupport.settingsKey: [DefaultsKey.commandBarLinks: legacy],
            ])!
            expect(CommandBarLinks.decode(legacyImport[DefaultsKey.commandBarLinks] as? Data).first?.requiresApproval == true,
                   "legacy backups also require local approval")

            // App-group declarations authorize cleanup only under a trusted
            // Apple signature and the matching developer team namespace.
            let team = "63LRF2GW5Z"
            let groups = ["63LRF2GW5Z.com.example.shared", "OTHER12345.com.other.shared",
                          "group.com.other.shared", "63LRF2GW5Z...escape", "63LRF2GW5Z.",
                          "63LRF2GW5Z.path/escape"]
            expect(UninstallerSupport.ownedGroupIDs(groups, teamID: team, hasTrustedSignature: false).isEmpty,
                   "ad hoc or invalid signatures cannot claim group-container deletion")
            expect(UninstallerSupport.ownedGroupIDs(groups, teamID: nil, hasTrustedSignature: true).isEmpty,
                   "a missing signing team cannot claim app groups")
            expect(UninstallerSupport.ownedGroupIDs(groups, teamID: team, hasTrustedSignature: true)
                   == ["63LRF2GW5Z.com.example.shared"],
                   "group authority rejects foreign teams, profile-only groups and malformed paths")

            // A development build must never authenticate by identifier alone.
            for invalid in [nil, "", "abc", "63lrf2gw5z", "63LRF2GW5Z\n", "\n63LRF2GW5Z", "63LRF2GW5Z\" or true"] as [String?] {
                expect(FanControlSigningPolicy.codeRequirement(identifier: "com.example.helper", teamID: invalid) == "never",
                       "missing or malformed Team ID fails closed")
            }
            expect(FanControlSigningPolicy.codeRequirement(identifier: "id\" or true", teamID: team) == "never",
                   "an identifier cannot inject a signing requirement")
            expect(FanControlSigningPolicy.codeRequirement(identifier: "com.example.helper\n", teamID: team) == "never",
                   "an identifier with a trailing newline fails closed")
            let requirementText = FanControlSigningPolicy.codeRequirement(identifier: "com.example.helper", teamID: team)
            var requirement: SecRequirement?
            expect(SecRequirementCreateWithString(requirementText as CFString, [], &requirement) == errSecSuccess,
                   "the team-pinned requirement parses with Apple's Security framework")
            var deny: SecRequirement?
            expect(SecRequirementCreateWithString("never" as CFString, [], &deny) == errSecSuccess,
                   "the fail-closed requirement is a valid Security requirement")

            func run(_ executable: String, _ arguments: [String]) -> Int32 {
                Shell.run(executable, arguments).0
            }
            func snapshot(_ source: URL, _ destination: URL, limit: Int = 1024) -> Int32 {
                run("/usr/bin/perl", ["-e", UpdateInstallerSupport.snapshotCopyProgram,
                                       source.path, destination.path, "\(limit)"])
            }
            let source = root.appendingPathComponent("download")
            let captured = root.appendingPathComponent("captured")
            try Data("signed-bytes-placeholder".utf8).write(to: source)
            expect(snapshot(source, captured) == 0, "the installer captures a bounded regular file")
            try Data("changed-after-capture".utf8).write(to: source)
            expect(try Data(contentsOf: captured) == Data("signed-bytes-placeholder".utf8),
                   "changing the download path cannot change the captured bytes")
            let sourceLink = root.appendingPathComponent("source-link")
            try fm.createSymbolicLink(at: sourceLink, withDestinationURL: source)
            expect(snapshot(sourceLink, root.appendingPathComponent("bad-source")) != 0,
                   "snapshot rejects a source symlink")
            let destinationLink = root.appendingPathComponent("destination-link")
            try fm.createSymbolicLink(at: destinationLink, withDestinationURL: source)
            expect(snapshot(captured, destinationLink) != 0,
                   "snapshot refuses an existing destination symlink")
            expect(try Data(contentsOf: source) == Data("changed-after-capture".utf8),
                   "destination symlinks never overwrite their target")
            expect(snapshot(source, root.appendingPathComponent("too-large"), limit: 1) != 0,
                   "the root snapshot enforces its size limit")
            expect(snapshot(root, root.appendingPathComponent("directory-copy")) != 0,
                   "the snapshot rejects directories")
            let fifo = root.appendingPathComponent("fifo")
            expect(mkfifo(fifo.path, 0o600) == 0, "a harmless FIFO fixture is created")
            let started = Date()
            expect(snapshot(fifo, root.appendingPathComponent("fifo-copy")) != 0
                   && Date().timeIntervalSince(started) < 3,
                   "a FIFO is rejected without waiting for a writer")

            let stage = root.appendingPathComponent("stage.app")
            let victim = root.appendingPathComponent("victim")
            let destination = root.appendingPathComponent("destination.app")
            try fm.createDirectory(at: stage, withIntermediateDirectories: true)
            try fm.createDirectory(at: victim, withIntermediateDirectories: true)
            try fm.createSymbolicLink(at: destination, withDestinationURL: victim)
            expect(run("/usr/bin/perl", ["-e", UpdateInstallerSupport.renameProgram,
                                         stage.path, destination.path]) != 0,
                   "atomic directory rename refuses a symlink destination")
            let victimContents = try fm.contentsOfDirectory(atPath: victim.path)
            expect(fm.fileExists(atPath: stage.path) && victimContents.isEmpty,
                   "a symlink swap leaves the stage and target untouched")
            try fm.removeItem(at: destination)
            expect(run("/usr/bin/perl", ["-e", UpdateInstallerSupport.renameProgram,
                                         stage.path, destination.path]) == 0,
                   "the same atomic operation installs at an absent exact destination")
            let installer = root.appendingPathComponent("installer.sh")
            try UpdateInstallerSupport.installerScript().write(to: installer, atomically: true, encoding: .utf8)
            expect(run("/bin/sh", ["-n", installer.path]) == 0,
                   "the generated installer and embedded Perl pass shell syntax validation")
            expect(UpdateInstallerSupport.permitsElevatedInstall(appPath: "/Applications/Menubench.app")
                   && !UpdateInstallerSupport.permitsElevatedInstall(appPath: "/Users/test/Menubench.app")
                   && !UpdateInstallerSupport.permitsElevatedInstall(appPath: "/Applications/../tmp/Menubench.app"),
                   "root replacement is limited to the canonical app location")
            for language in AppLanguage.allCases {
                let strings = SecurityFeatureStrings.forLanguage(language)
                expect(strings.reviewScriptBodyFormat.components(separatedBy: "%@").count == 2
                       && !strings.importedScriptDisabled.isEmpty && !strings.manualUpdateBody.isEmpty,
                       "security prompts exist with one path placeholder in \(language.rawValue)")
            }
        } catch {
            try? fm.removeItem(at: root)
            expect(false, "security regression fixture failed: \(error)")
        }
    }
}
