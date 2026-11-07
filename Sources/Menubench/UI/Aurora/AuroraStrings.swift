// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The few labels the Aurora panel adds; everything else reuses the
/// existing section and metric strings.
enum AuroraStrings {
    /// The home tile that opens the full tools page.
    static func allTools(_ language: AppLanguage) -> String {
        switch language {
        case .enUS: return "All tools"
        case .ptBR: return "Todas"
        case .tr: return "Tümü"
        case .ru: return "Все"
        case .es: return "Todas"
        case .de: return "Alle"
        case .fr: return "Tous"
        case .it: return "Tutti"
        case .ja: return "すべて"
        case .ko: return "전체"
        case .zhHans: return "全部"
        case .zhTW: return "全部"
        case .zhHK: return "全部"
        }
    }
}
