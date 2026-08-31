// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

struct MediaDownloaderView: View {
    @ObservedObject private var l10n = L10n.shared
    @StateObject private var service = MediaDownloadService()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(DefaultsKey.mediaDownloadFormat) private var formatRaw = MediaDownloadFormat.mp4.rawValue
    @AppStorage(DefaultsKey.mediaDownloadVideoQuality) private var videoQualityRaw = MediaDownloadVideoQuality.p1080.rawValue
    @AppStorage(DefaultsKey.mediaDownloadAudioQuality) private var audioQualityRaw = MediaDownloadAudioQuality.best.rawValue
    @AppStorage(DefaultsKey.mediaDownloadDestination) private var destinationPath = ""

    @State private var sourceText = ""
    @State private var validationMessage: String?
    @State private var installCommandCopied = false
    @State private var copyResetTask: Task<Void, Never>?

    let compact: Bool

    private var strings: MediaDownloadStrings {
        MediaDownloadStrings.localized(l10n.language)
    }

    private var format: MediaDownloadFormat {
        MediaDownloadFormat.sanitized(formatRaw)
    }

    private var destinationURL: URL {
        if !destinationPath.isEmpty {
            return URL(fileURLWithPath: destinationPath, isDirectory: true)
        }
        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
                .appendingPathComponent("Downloads", isDirectory: true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? Theme.Space.xs : Theme.Space.sm) {
            introduction
            sourceCard
            optionsCard
            requirementsCard
            actionArea
        }
        .tint(Theme.accent)
        .onAppear {
            if destinationPath.isEmpty { destinationPath = destinationURL.path }
            service.refreshDependencies()
        }
        .onDisappear {
            copyResetTask?.cancel()
            if service.isRunning { service.cancel() }
        }
    }

    private var introduction: some View {
        HStack(alignment: .top, spacing: Theme.Space.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .fill(Theme.accentWash(for: colorScheme))
                Image(systemName: "arrow.down.to.line.compact")
                    .font(.system(size: compact ? 16 : 19, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            .frame(width: compact ? 38 : 44, height: compact ? 38 : 44)

            VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                Text(strings.title)
                    .font(.system(size: compact ? 16 : 21, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.warmInk(for: colorScheme))
                Text(strings.subtitle)
                    .font(.system(size: compact ? 10.5 : 12.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Theme.Space.xxs)
    }

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(strings.linkLabel)
                .font(.system(size: 11, weight: .semibold, design: .rounded))

            HStack(spacing: Theme.Space.xs) {
                TextField(strings.urlPlaceholder, text: $sourceText)
                    .textFieldStyle(.plain)
                    .font(.system(size: compact ? 11 : 12.5))
                    .onSubmit(startDownload)
                    .disabled(service.isRunning)

                Button(strings.paste, action: pasteLink)
                    .buttonStyle(.borderless)
                    .font(.system(size: 11, weight: .semibold))
                    .disabled(service.isRunning)
            }
            .padding(.horizontal, Theme.Space.sm)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .fill(PanelSurface.controlFill(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .strokeBorder(validationMessage == nil ? PanelSurface.border(for: colorScheme) : Theme.accent,
                                  lineWidth: 1)
            )

            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .panelCard()
    }

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(strings.format)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                Picker(strings.format, selection: $formatRaw) {
                    ForEach(MediaDownloadFormat.allCases) { item in
                        Text(item.rawValue.uppercased()).tag(item.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .disabled(service.isRunning)
            }

            Divider()

            HStack(alignment: .center, spacing: Theme.Space.md) {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text(strings.quality)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    qualityControl
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: Theme.Space.xs) {
                    Text(strings.saveTo)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    Button(action: chooseDestination) {
                        Label(destinationURL.lastPathComponent, systemImage: "folder")
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .help(destinationURL.path)
                    .disabled(service.isRunning)
                }
            }
        }
        .panelCard()
    }

    @ViewBuilder
    private var qualityControl: some View {
        if format.isAudioOnly {
            if format == .wav {
                Text(strings.lossless)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 22)
            } else {
                Picker(strings.quality, selection: $audioQualityRaw) {
                    ForEach(MediaDownloadAudioQuality.allCases) { quality in
                        Text(audioQualityTitle(quality)).tag(quality.rawValue)
                    }
                }
                .labelsHidden()
                .frame(width: compact ? 132 : 155)
                .disabled(service.isRunning)
            }
        } else {
            Picker(strings.quality, selection: $videoQualityRaw) {
                ForEach(MediaDownloadVideoQuality.allCases) { quality in
                    Text(videoQualityTitle(quality)).tag(quality.rawValue)
                }
            }
            .labelsHidden()
            .frame(width: compact ? 132 : 155)
            .disabled(service.isRunning)
        }
    }

    private var requirementsCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            HStack {
                Text(strings.requirements)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                Spacer(minLength: 0)
                Button {
                    service.refreshDependencies()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help(strings.requirements)
                .disabled(service.isRunning)
            }

            HStack(spacing: Theme.Space.sm) {
                dependencyStatus("yt-dlp", available: service.dependencies.ytDLP != nil)
                dependencyStatus("FFmpeg", available: service.dependencies.ffmpeg != nil)
                dependencyStatus("Deno", available: service.dependencies.deno != nil)
            }

            if service.dependencies.isReadyForYouTube {
                Label(strings.allReady, systemImage: "checkmark.circle.fill")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
            } else {
                let missing = service.dependencies.missingNames.joined(separator: ", ")
                VStack(alignment: .leading, spacing: Theme.Space.xxs) {
                    Label(String(format: strings.missingFormat, missing),
                          systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Theme.accent)
                    Text(strings.installCaption)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Button(action: copyInstallCommand) {
                        Label(installCommandCopied ? strings.copied : strings.copyInstall,
                              systemImage: installCommandCopied ? "checkmark" : "doc.on.doc")
                    }
                    .controlSize(.small)
                }
            }
        }
        .panelCard()
    }

    @ViewBuilder
    private func dependencyStatus(_ name: String, available: Bool) -> some View {
        HStack(spacing: Theme.Space.xxs) {
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(available ? Color.secondary : Theme.accent)
            Text(name)
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
        }
        .accessibilityLabel("\(name): \(available ? strings.allReady : strings.installCaption)")
    }

    private var actionArea: some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            stateView

            HStack(spacing: Theme.Space.xs) {
                if service.isRunning {
                    Button(action: service.cancel) {
                        Label(strings.cancel, systemImage: "xmark")
                    }
                } else {
                    Button(action: startDownload) {
                        Label(strings.start, systemImage: "arrow.down.to.line.compact")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                              || !service.dependencies.isReadyForYouTube)
                }

                if case let .completed(url) = service.state {
                    Button {
                        reveal(url)
                    } label: {
                        Label(strings.reveal, systemImage: "finder")
                    }
                }
                Spacer(minLength: 0)
            }
            .controlSize(compact ? .small : .regular)

            Label(strings.legalNote, systemImage: "hand.raised")
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var stateView: some View {
        switch service.state {
        case .idle:
            EmptyView()
        case let .running(progress):
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                HStack {
                    Label(stageTitle(progress.stage), systemImage: "arrow.down.circle.fill")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    Spacer(minLength: 0)
                    Text(progress.fraction, format: .percent.precision(.fractionLength(0)))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                }
                ProgressView(value: progress.fraction)
                    .progressViewStyle(.linear)
                HStack(spacing: Theme.Space.md) {
                    if let speed = progress.speed {
                        Text("\(strings.speed) \(speed)")
                    }
                    if let eta = progress.eta {
                        Text("\(strings.eta) \(eta)")
                    }
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary)
            }
            .padding(Theme.Space.sm)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.accentWash(for: colorScheme))
            )
            .transition(.opacity)
        case let .completed(url):
            Label("\(strings.completed): \(url.lastPathComponent)", systemImage: "checkmark.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .transition(.opacity)
        case let .failed(message):
            Label(message, systemImage: "exclamationmark.circle.fill")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Theme.accent)
                .fixedSize(horizontal: false, vertical: true)
                .transition(.opacity)
        case .cancelled:
            Label(strings.cancelled, systemImage: "xmark.circle")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
                .transition(.opacity)
        }
    }

    private func startDownload() {
        guard let sourceURL = MediaDownloadSupport.validatedRemoteURL(sourceText) else {
            validationMessage = strings.invalidURL
            return
        }
        validationMessage = nil
        let options = MediaDownloadOptions(
            format: format,
            videoQuality: MediaDownloadVideoQuality.sanitized(videoQualityRaw),
            audioQuality: MediaDownloadAudioQuality.sanitized(audioQualityRaw),
            destinationDirectory: destinationURL
        )
        if reduceMotion {
            service.start(sourceURL: sourceURL, options: options)
        } else {
            withAnimation(.easeOut(duration: 0.2)) {
                service.start(sourceURL: sourceURL, options: options)
            }
        }
    }

    private func pasteLink() {
        guard let value = NSPasteboard.general.string(forType: .string) else { return }
        sourceText = value.trimmingCharacters(in: .whitespacesAndNewlines)
        validationMessage = nil
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = destinationURL
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            if panel.runModal() == .OK, let url = panel.url {
                destinationPath = url.path
            }
            QuickLauncherService.shared.refocusAfterModal()
        }
    }

    private func copyInstallCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(MediaDownloadSupport.installCommand, forType: .string)
        installCommandCopied = true
        copyResetTask?.cancel()
        copyResetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            installCommandCopied = false
        }
    }

    private func reveal(_ url: URL) {
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    private func stageTitle(_ stage: MediaDownloadStage) -> String {
        switch stage {
        case .preparing: return strings.preparing
        case .downloading: return strings.downloading
        case .merging: return strings.merging
        case .converting: return strings.converting
        }
    }

    private func videoQualityTitle(_ quality: MediaDownloadVideoQuality) -> String {
        quality.maximumHeight.map { "\($0)p" } ?? strings.best
    }

    private func audioQualityTitle(_ quality: MediaDownloadAudioQuality) -> String {
        switch quality {
        case .best: return strings.best
        case .kbps320: return "320 kbps"
        case .kbps256: return "256 kbps"
        case .kbps192: return "192 kbps"
        case .kbps128: return "128 kbps"
        }
    }
}
