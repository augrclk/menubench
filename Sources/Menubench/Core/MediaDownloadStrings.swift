// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct MediaDownloadStrings {
    let toolName: String
    let title: String
    let subtitle: String
    let linkLabel: String
    let urlPlaceholder: String
    let paste: String
    let format: String
    let quality: String
    let best: String
    let lossless: String
    let saveTo: String
    let chooseFolder: String
    let requirements: String
    let allReady: String
    let missingFormat: String
    let installCaption: String
    let copyInstall: String
    let copied: String
    let legalNote: String
    let start: String
    let cancel: String
    let reveal: String
    let completed: String
    let cancelled: String
    let invalidURL: String
    let preparing: String
    let downloading: String
    let merging: String
    let converting: String
    let speed: String
    let eta: String

    static func localized(_ language: AppLanguage) -> MediaDownloadStrings {
        language == .tr ? .tr : .enUS
    }
}

extension MediaDownloadStrings {
    static let enUS = MediaDownloadStrings(
        toolName: "Download",
        title: "From link to local file.",
        subtitle: "Save a YouTube or yt-dlp supported link as MP4, MOV, MP3 or WAV.",
        linkLabel: "Video or audio link",
        urlPlaceholder: "https://www.youtube.com/watch?v=…",
        paste: "Paste",
        format: "Format",
        quality: "Quality",
        best: "Best available",
        lossless: "Source quality",
        saveTo: "Save to",
        chooseFolder: "Choose folder",
        requirements: "Download engine",
        allReady: "yt-dlp, FFmpeg and Deno are ready.",
        missingFormat: "Missing: %@",
        installCaption: "Install the missing command-line tools with Homebrew.",
        copyInstall: "Copy install command",
        copied: "Copied",
        legalNote: "Download only content you own or have permission to save.",
        start: "Download",
        cancel: "Cancel",
        reveal: "Show in Finder",
        completed: "Saved to your Mac",
        cancelled: "Download cancelled",
        invalidURL: "Enter a complete http or https link, then try again.",
        preparing: "Preparing",
        downloading: "Downloading",
        merging: "Joining video and audio",
        converting: "Converting",
        speed: "Speed",
        eta: "Remaining"
    )

    static let tr = MediaDownloadStrings(
        toolName: "İndir",
        title: "Bağlantıdan yerel dosyaya.",
        subtitle: "YouTube veya yt-dlp destekli bir bağlantıyı MP4, MOV, MP3 ya da WAV olarak kaydet.",
        linkLabel: "Video veya müzik bağlantısı",
        urlPlaceholder: "https://www.youtube.com/watch?v=…",
        paste: "Yapıştır",
        format: "Biçim",
        quality: "Kalite",
        best: "En iyi kalite",
        lossless: "Kaynak kalitesi",
        saveTo: "Kayıt yeri",
        chooseFolder: "Klasör seç",
        requirements: "İndirme altyapısı",
        allReady: "yt-dlp, FFmpeg ve Deno hazır.",
        missingFormat: "Eksik: %@",
        installCaption: "Eksik komut satırı araçlarını Homebrew ile kur.",
        copyInstall: "Kurulum komutunu kopyala",
        copied: "Kopyalandı",
        legalNote: "Yalnızca sahibi olduğun veya kaydetme iznin bulunan içerikleri indir.",
        start: "İndirmeyi başlat",
        cancel: "İptal",
        reveal: "Finder’da göster",
        completed: "Mac’ine kaydedildi",
        cancelled: "İndirme iptal edildi",
        invalidURL: "Tam bir http veya https bağlantısı girip yeniden dene.",
        preparing: "Hazırlanıyor",
        downloading: "İndiriliyor",
        merging: "Video ve ses birleştiriliyor",
        converting: "Dönüştürülüyor",
        speed: "Hız",
        eta: "Kalan"
    )
}
