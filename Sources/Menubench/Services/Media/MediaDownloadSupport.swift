// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum MediaDownloadFormat: String, CaseIterable, Codable, Identifiable {
    case mp4, mov, mp3, wav

    var id: String { rawValue }
    var fileExtension: String { rawValue }
    var isAudioOnly: Bool { self == .mp3 || self == .wav }

    static func sanitized(_ rawValue: String) -> MediaDownloadFormat {
        MediaDownloadFormat(rawValue: rawValue) ?? .mp4
    }
}

enum MediaDownloadVideoQuality: String, CaseIterable, Codable, Identifiable {
    case best, p2160, p1440, p1080, p720, p480, p360

    var id: String { rawValue }

    var maximumHeight: Int? {
        switch self {
        case .best: return nil
        case .p2160: return 2160
        case .p1440: return 1440
        case .p1080: return 1080
        case .p720: return 720
        case .p480: return 480
        case .p360: return 360
        }
    }

    static func sanitized(_ rawValue: String) -> MediaDownloadVideoQuality {
        MediaDownloadVideoQuality(rawValue: rawValue) ?? .p1080
    }
}

enum MediaDownloadAudioQuality: String, CaseIterable, Codable, Identifiable {
    case best, kbps320, kbps256, kbps192, kbps128

    var id: String { rawValue }

    var ytDLPValue: String {
        switch self {
        case .best: return "0"
        case .kbps320: return "320K"
        case .kbps256: return "256K"
        case .kbps192: return "192K"
        case .kbps128: return "128K"
        }
    }

    static func sanitized(_ rawValue: String) -> MediaDownloadAudioQuality {
        MediaDownloadAudioQuality(rawValue: rawValue) ?? .best
    }
}

struct MediaDownloadOptions: Equatable {
    var format: MediaDownloadFormat
    var videoQuality: MediaDownloadVideoQuality
    var audioQuality: MediaDownloadAudioQuality
    var destinationDirectory: URL
}

struct MediaDownloadDependencies: Equatable {
    var ytDLP: URL?
    var ffmpeg: URL?
    var deno: URL?

    var isReadyForYouTube: Bool {
        ytDLP != nil && ffmpeg != nil && deno != nil
    }

    var missingNames: [String] {
        var names: [String] = []
        if ytDLP == nil { names.append("yt-dlp") }
        if ffmpeg == nil { names.append("ffmpeg") }
        if deno == nil { names.append("Deno") }
        return names
    }
}

enum MediaDownloadStage: String, Equatable {
    case preparing
    case downloading
    case merging
    case converting
}

enum MediaDownloadOutputEvent: Equatable {
    case progress(fraction: Double, speed: String?, eta: String?)
    case destination(URL)
    case stage(MediaDownloadStage)
    case ignored
}

enum MediaDownloadSupport {
    static let installCommand = "brew install yt-dlp ffmpeg deno"
    static let progressMarker = "__MENUBENCH_PROGRESS__"
    static let fileMarker = "__MENUBENCH_FILE__"

    static func validatedRemoteURL(_ rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              components.host?.isEmpty == false,
              let url = components.url else {
            return nil
        }
        return url
    }

    static func dependencies(environment: [String: String] = ProcessInfo.processInfo.environment,
                             fileManager: FileManager = .default) -> MediaDownloadDependencies {
        MediaDownloadDependencies(
            ytDLP: executableURL(named: "yt-dlp", environment: environment, fileManager: fileManager),
            ffmpeg: executableURL(named: "ffmpeg", environment: environment, fileManager: fileManager),
            deno: executableURL(named: "deno", environment: environment, fileManager: fileManager)
        )
    }

    static func executableURL(named name: String,
                              environment: [String: String] = ProcessInfo.processInfo.environment,
                              fileManager: FileManager = .default) -> URL? {
        var directories = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
        if let path = environment["PATH"] {
            directories.append(contentsOf: path.split(separator: ":").map(String.init))
        }
        var seen = Set<String>()
        for directory in directories where !directory.isEmpty && seen.insert(directory).inserted {
            let candidate = URL(fileURLWithPath: directory, isDirectory: true)
                .appendingPathComponent(name, isDirectory: false)
            if fileManager.isExecutableFile(atPath: candidate.path) {
                return candidate.standardizedFileURL
            }
        }
        return nil
    }

    static func arguments(sourceURL: URL,
                          options: MediaDownloadOptions,
                          dependencies: MediaDownloadDependencies) -> [String] {
        var arguments = [
            "--no-playlist",
            "--newline",
            "--no-colors",
            "--progress",
            "--progress-template",
            "download:\(progressMarker)%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s",
            "--print",
            "after_move:\(fileMarker)%(filepath)s",
            "--paths", options.destinationDirectory.path,
            "--output", "%(title).180B [%(id)s].%(ext)s",
            "--trim-filenames", "180",
            "--no-overwrites",
        ]

        if let ffmpeg = dependencies.ffmpeg {
            arguments.append(contentsOf: ["--ffmpeg-location", ffmpeg.path])
        }
        if let deno = dependencies.deno {
            arguments.append(contentsOf: ["--js-runtimes", "deno:\(deno.path)"])
        }

        switch options.format {
        case .mp4:
            arguments.append(contentsOf: [
                "-f", videoFormatSelector(quality: options.videoQuality),
                "--merge-output-format", "mp4",
                "--recode-video", "mp4",
            ])
        case .mov:
            arguments.append(contentsOf: [
                "-f", videoFormatSelector(quality: options.videoQuality),
                "--recode-video", "mov",
            ])
        case .mp3:
            arguments.append(contentsOf: [
                "-f", "ba/b",
                "-x",
                "--audio-format", "mp3",
                "--audio-quality", options.audioQuality.ytDLPValue,
            ])
        case .wav:
            arguments.append(contentsOf: [
                "-f", "ba/b",
                "-x",
                "--audio-format", "wav",
            ])
        }
        arguments.append(sourceURL.absoluteString)
        return arguments
    }

    static func videoFormatSelector(quality: MediaDownloadVideoQuality) -> String {
        guard let height = quality.maximumHeight else { return "bv*+ba/b" }
        return "bv*[height<=?\(height)]+ba/b[height<=?\(height)]/bv*+ba/b"
    }

    static func parseOutputLine(_ rawLine: String) -> MediaDownloadOutputEvent {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if let markerRange = line.range(of: progressMarker) {
            let fields = line[markerRange.upperBound...].split(separator: "|", omittingEmptySubsequences: false)
            let percentText = fields.first.map(String.init)?
                .replacingOccurrences(of: "%", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard let percent = Double(percentText) else { return .ignored }
            let speed = normalizedField(fields.count > 1 ? String(fields[1]) : nil)
            let eta = normalizedField(fields.count > 2 ? String(fields[2]) : nil)
            return .progress(fraction: min(1, max(0, percent / 100)), speed: speed, eta: eta)
        }
        if let markerRange = line.range(of: fileMarker) {
            let path = String(line[markerRange.upperBound...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else { return .ignored }
            return .destination(URL(fileURLWithPath: path))
        }
        if line.hasPrefix("[download]") { return .stage(.downloading) }
        if line.hasPrefix("[Merger]") { return .stage(.merging) }
        if line.hasPrefix("[ExtractAudio]") || line.hasPrefix("[VideoConvertor]")
            || line.hasPrefix("[VideoRemuxer]") || line.hasPrefix("[Fixup") {
            return .stage(.converting)
        }
        return .ignored
    }

    private static func normalizedField(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == "NA" || trimmed == "Unknown" { return nil }
        return trimmed
    }
}
