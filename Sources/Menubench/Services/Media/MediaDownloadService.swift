// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct MediaDownloadProgress: Equatable {
    var fraction: Double
    var speed: String?
    var eta: String?
    var stage: MediaDownloadStage
}

enum MediaDownloadState: Equatable {
    case idle
    case running(MediaDownloadProgress)
    case completed(URL)
    case failed(MediaDownloadFailure)
    case cancelled
}

enum MediaDownloadFailure: Equatable {
    case message(String)
    case temporaryAccessDenied(engineRefreshAttempted: Bool)
}

@MainActor
final class MediaDownloadService: ObservableObject {
    private enum RecoveryCommand {
        case updateMetadata
        case upgradeYtDLP

        var arguments: [String] {
            switch self {
            case .updateMetadata: return ["update"]
            case .upgradeYtDLP: return ["upgrade", "yt-dlp"]
            }
        }
    }

    @Published private(set) var state: MediaDownloadState = .idle
    @Published private(set) var dependencies = MediaDownloadDependencies()

    private let workerQueue = DispatchQueue(label: "com.menubench.media-download", qos: .userInitiated)
    private var operationID: UUID?
    private var activeProcess: Process?
    private var pendingRetry: DispatchWorkItem?

    init() {
        refreshDependencies()
    }

    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    func refreshDependencies() {
        dependencies = MediaDownloadSupport.dependencies()
    }

    func reset() {
        cancelProcess(publishCancelled: false)
        state = .idle
    }

    func cancel() {
        cancelProcess(publishCancelled: true)
    }

    func start(sourceURL: URL, options: MediaDownloadOptions) {
        refreshDependencies()
        guard dependencies.isReadyForYouTube, let ytDLP = dependencies.ytDLP else {
            state = .failed(.message("Missing tools: \(dependencies.missingNames.joined(separator: ", "))."))
            return
        }

        do {
            try FileManager.default.createDirectory(at: options.destinationDirectory,
                                                    withIntermediateDirectories: true)
        } catch {
            state = .failed(.message(error.localizedDescription))
            return
        }

        cancelProcess(publishCancelled: false)
        let id = UUID()
        operationID = id
        launchDownload(sourceURL: sourceURL,
                       options: options,
                       ytDLP: ytDLP,
                       operationID: id,
                       attempt: 0,
                       updateAttempted: false)
    }

    private func launchDownload(sourceURL: URL,
                                options: MediaDownloadOptions,
                                ytDLP: URL,
                                operationID id: UUID,
                                attempt: Int,
                                updateAttempted: Bool) {
        guard operationID == id else { return }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = ytDLP
        process.arguments = MediaDownloadSupport.arguments(sourceURL: sourceURL,
                                                           options: options,
                                                           dependencies: dependencies)
        process.standardOutput = pipe
        process.standardError = pipe
        activeProcess = process
        state = .running(MediaDownloadProgress(fraction: 0,
                                               speed: nil,
                                               eta: nil,
                                               stage: attempt == 0 ? .preparing : .retrying))

        workerQueue.async { [weak self] in
            var pending = Data()
            var recentLines: [String] = []
            var finalDestination: URL?

            func consume(_ line: String) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                recentLines.append(trimmed)
                if recentLines.count > 40 { recentLines.removeFirst(recentLines.count - 40) }
                let event = MediaDownloadSupport.parseOutputLine(trimmed)
                if case let .destination(url) = event { finalDestination = url }
                Task { @MainActor [weak self] in
                    self?.handle(event, operationID: id)
                }
            }

            do {
                try process.run()
                let handle = pipe.fileHandleForReading
                while let data = try handle.read(upToCount: 8_192), !data.isEmpty {
                    pending.append(data)
                    while let newline = pending.firstIndex(of: 0x0A) {
                        let lineData = pending.prefix(upTo: newline)
                        pending.removeSubrange(...newline)
                        if let line = String(data: lineData, encoding: .utf8) { consume(line) }
                    }
                }
                if !pending.isEmpty, let line = String(data: pending, encoding: .utf8) {
                    consume(line)
                }
                process.waitUntilExit()
                let status = process.terminationStatus
                Task { @MainActor [weak self] in
                    self?.finish(operationID: id,
                                 status: status,
                                 destination: finalDestination ?? options.destinationDirectory,
                                 recentLines: recentLines,
                                 sourceURL: sourceURL,
                                 options: options,
                                 ytDLP: ytDLP,
                                 attempt: attempt,
                                 updateAttempted: updateAttempted)
                }
            } catch {
                Task { @MainActor [weak self] in
                    guard self?.operationID == id else { return }
                    self?.activeProcess = nil
                    self?.operationID = nil
                    self?.state = .failed(.message(error.localizedDescription))
                }
            }
        }
    }

    private func handle(_ event: MediaDownloadOutputEvent, operationID id: UUID) {
        guard operationID == id else { return }
        switch event {
        case let .progress(fraction, speed, eta):
            let priorStage: MediaDownloadStage
            if case let .running(progress) = state {
                priorStage = progress.stage == .preparing ? .downloading : progress.stage
            } else {
                priorStage = .downloading
            }
            state = .running(MediaDownloadProgress(fraction: fraction,
                                                   speed: speed,
                                                   eta: eta,
                                                   stage: priorStage))
        case let .stage(stage):
            let progress: MediaDownloadProgress
            if case let .running(current) = state {
                progress = MediaDownloadProgress(fraction: current.fraction,
                                                 speed: current.speed,
                                                 eta: current.eta,
                                                 stage: stage)
            } else {
                progress = MediaDownloadProgress(fraction: 0,
                                                 speed: nil,
                                                 eta: nil,
                                                 stage: stage)
            }
            state = .running(progress)
        case .destination, .ignored:
            break
        }
    }

    private func finish(operationID id: UUID,
                        status: Int32,
                        destination: URL,
                        recentLines: [String],
                        sourceURL: URL,
                        options: MediaDownloadOptions,
                        ytDLP: URL,
                        attempt: Int,
                        updateAttempted: Bool) {
        guard operationID == id else { return }
        activeProcess = nil
        if status == 0 {
            operationID = nil
            state = .completed(destination)
            return
        }

        let brewURL = MediaDownloadSupport.executableURL(named: "brew")
        switch MediaDownloadSupport.recoveryAction(recentLines: recentLines,
                                                   attempt: attempt,
                                                   updateAttempted: updateAttempted,
                                                   homebrewAvailable: brewURL != nil) {
        case let .retry(delay):
            scheduleRetry(sourceURL: sourceURL,
                          options: options,
                          ytDLP: ytDLP,
                          operationID: id,
                          attempt: attempt + 1,
                          updateAttempted: updateAttempted,
                          after: delay)
            return
        case .updateEngine:
            guard let brewURL else {
                scheduleRetry(sourceURL: sourceURL,
                              options: options,
                              ytDLP: ytDLP,
                              operationID: id,
                              attempt: attempt + 1,
                              updateAttempted: true,
                              after: 3)
                return
            }
            beginEngineUpdate(brewURL: brewURL,
                              sourceURL: sourceURL,
                              options: options,
                              ytDLP: ytDLP,
                              operationID: id,
                              nextAttempt: attempt + 1)
            return
        case .fail:
            break
        }

        operationID = nil
        if MediaDownloadSupport.isHTTP403(recentLines) {
            state = .failed(.temporaryAccessDenied(engineRefreshAttempted: updateAttempted))
            return
        }
        let usefulLine = recentLines.reversed().first { line in
            !line.hasPrefix(MediaDownloadSupport.progressMarker)
                && !line.contains(MediaDownloadSupport.fileMarker)
        }
        let message = usefulLine.map { String($0.suffix(420)) }
            ?? "yt-dlp exited with status \(status)."
        state = .failed(.message(message))
    }

    private func scheduleRetry(sourceURL: URL,
                               options: MediaDownloadOptions,
                               ytDLP: URL,
                               operationID id: UUID,
                               attempt: Int,
                               updateAttempted: Bool,
                               after delay: TimeInterval) {
        guard operationID == id else { return }
        state = .running(MediaDownloadProgress(fraction: 0,
                                               speed: nil,
                                               eta: nil,
                                               stage: .retrying))
        pendingRetry?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.operationID == id else { return }
                self.pendingRetry = nil
                self.launchDownload(sourceURL: sourceURL,
                                    options: options,
                                    ytDLP: ytDLP,
                                    operationID: id,
                                    attempt: attempt,
                                    updateAttempted: updateAttempted)
            }
        }
        pendingRetry = work
        workerQueue.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func beginEngineUpdate(brewURL: URL,
                                   sourceURL: URL,
                                   options: MediaDownloadOptions,
                                   ytDLP: URL,
                                   operationID id: UUID,
                                   nextAttempt: Int) {
        guard operationID == id else { return }
        state = .running(MediaDownloadProgress(fraction: 0,
                                               speed: nil,
                                               eta: nil,
                                               stage: .updatingEngine))
        launchRecoveryCommand(.updateMetadata,
                              brewURL: brewURL,
                              sourceURL: sourceURL,
                              options: options,
                              ytDLP: ytDLP,
                              operationID: id,
                              nextAttempt: nextAttempt)
    }

    private func launchRecoveryCommand(_ command: RecoveryCommand,
                                       brewURL: URL,
                                       sourceURL: URL,
                                       options: MediaDownloadOptions,
                                       ytDLP: URL,
                                       operationID id: UUID,
                                       nextAttempt: Int) {
        guard operationID == id else { return }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = brewURL
        process.arguments = command.arguments
        var environment = ProcessInfo.processInfo.environment
        environment["HOMEBREW_NO_ANALYTICS"] = "1"
        environment["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        environment["HOMEBREW_NO_ENV_HINTS"] = "1"
        environment["HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK"] = "1"
        process.environment = environment
        process.standardOutput = pipe
        process.standardError = pipe
        activeProcess = process

        workerQueue.async { [weak self] in
            let status: Int32
            do {
                try process.run()
                _ = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                status = process.terminationStatus
            } catch {
                status = -1
            }
            Task { @MainActor [weak self] in
                self?.finishRecoveryCommand(command,
                                            status: status,
                                            brewURL: brewURL,
                                            sourceURL: sourceURL,
                                            options: options,
                                            ytDLP: ytDLP,
                                            operationID: id,
                                            nextAttempt: nextAttempt)
            }
        }
    }

    private func finishRecoveryCommand(_ command: RecoveryCommand,
                                       status: Int32,
                                       brewURL: URL,
                                       sourceURL: URL,
                                       options: MediaDownloadOptions,
                                       ytDLP: URL,
                                       operationID id: UUID,
                                       nextAttempt: Int) {
        guard operationID == id else { return }
        activeProcess = nil
        switch command {
        case .updateMetadata:
            launchRecoveryCommand(.upgradeYtDLP,
                                  brewURL: brewURL,
                                  sourceURL: sourceURL,
                                  options: options,
                                  ytDLP: ytDLP,
                                  operationID: id,
                                  nextAttempt: nextAttempt)
        case .upgradeYtDLP:
            refreshDependencies()
            let refreshedYtDLP = dependencies.ytDLP ?? ytDLP
            scheduleRetry(sourceURL: sourceURL,
                          options: options,
                          ytDLP: refreshedYtDLP,
                          operationID: id,
                          attempt: nextAttempt,
                          updateAttempted: true,
                          after: status == 0 ? 0.4 : 3)
        }
    }

    private func cancelProcess(publishCancelled: Bool) {
        pendingRetry?.cancel()
        pendingRetry = nil
        operationID = nil
        if let process = activeProcess, process.isRunning {
            process.terminate()
        }
        activeProcess = nil
        if publishCancelled { state = .cancelled }
    }
}
