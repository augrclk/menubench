// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation
import Security

enum FanControlIdentifiers {
    /// Read the signer at runtime so a GPL fork can be signed by its own
    /// Developer ID without weakening the privileged helper handshake.
    static let teamID: String? = {
        var ownCode: SecCode?
        guard SecCodeCopySelf(SecCSFlags(), &ownCode) == errSecSuccess,
              let ownCode else { return nil }
        var ownStaticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(ownCode, SecCSFlags(), &ownStaticCode) == errSecSuccess,
              let ownStaticCode else { return nil }
        var signingInfo: CFDictionary?
        guard SecCodeCopySigningInformation(
            ownStaticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &signingInfo
        ) == errSecSuccess,
              let info = signingInfo as? [String: Any] else { return nil }
        return info[kSecCodeInfoTeamIdentifier as String] as? String
    }()

    #if MENUBENCH_DEVELOPMENT
    static let appBundleID = "com.celikugurdev.menubench.dev"
    #else
    static let appBundleID = "com.celikugurdev.menubench"
    #endif

    static let helperID = "\(appBundleID).fan-control"
    static let plistName = "\(helperID).plist"

    static let appCodeRequirement = codeRequirement(identifier: appBundleID)
    static let helperCodeRequirement = codeRequirement(identifier: helperID)

    private static func codeRequirement(identifier: String) -> String {
        guard let teamID, !teamID.isEmpty else {
            // Ad-hoc and local self-signed development identities do not carry
            // an Apple Team ID. The fixed, fork-owned identifier still prevents
            // an unrelated process from attaching to the development helper.
            return "identifier \"\(identifier)\""
        }
        return "anchor apple generic and certificate leaf[subject.OU] = \"\(teamID)\" "
            + "and identifier \"\(identifier)\""
    }
}

@objc protocol FanControlXPCProtocol {
    func status(withReply reply: @escaping (Data) -> Void)
    func startMaximumCooling(withReply reply: @escaping (Data) -> Void)
    func applyConfiguration(_ configuration: Data, withReply reply: @escaping (Data) -> Void)
    func heartbeat(withReply reply: @escaping (Data) -> Void)
    func restoreAutomatic(withReply reply: @escaping (Data) -> Void)
}

enum FanControlIPC {
    static func encode(_ response: FanControlResponse) -> Data {
        // Every value in this closed response model is JSON encodable. Keeping
        // one deterministic fallback avoids ever violating the XPC reply shape.
        (try? JSONEncoder().encode(response))
            ?? Data(#"{"succeeded":false,"snapshot":{"fans":[],"isCooling":false},"error":"controlFailed"}"#.utf8)
    }

    static func decode(_ data: Data) -> FanControlResponse? {
        try? JSONDecoder().decode(FanControlResponse.self, from: data)
    }

    static func encode(_ configuration: FanControlConfiguration) -> Data? {
        try? JSONEncoder().encode(configuration)
    }

    static func decodeConfiguration(_ data: Data) -> FanControlConfiguration? {
        guard let configuration = try? JSONDecoder().decode(FanControlConfiguration.self,
                                                              from: data),
              FanControlPolicy.validConfiguration(configuration) else { return nil }
        return configuration
    }
}
