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
    case failed(String)
    case cancelled
}

@MainActor
final class MediaDownloadService: ObservableObject {
    @Published private(set) var state: MediaDownloadState = .idle
    @Published private(set) var dependencies = MediaDownloadDependencies()

    private let workerQueue = DispatchQueue(label: "com.menubench.media-download", qos: .userInitiated)
    private var operationID: UUID?
    private var activeProcess: Process?

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
            state = .failed("Missing tools: \(dependencies.missingNames.joined(separator: ", ")).")
            return
        }

        do {
            try FileManager.default.createDirectory(at: options.destinationDirectory,
                                                    withIntermediateDirectories: true)
        } catch {
            state = .failed(error.localizedDescription)
            return
        }

        cancelProcess(publishCancelled: false)
        let id = UUID()
        operationID = id
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
                                               stage: .preparing))

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
                                 recentLines: recentLines)
                }
            } catch {
                Task { @MainActor [weak self] in
                    guard self?.operationID == id else { return }
                    self?.activeProcess = nil
                    self?.operationID = nil
                    self?.state = .failed(error.localizedDescription)
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
                        recentLines: [String]) {
        guard operationID == id else { return }
        operationID = nil
        activeProcess = nil
        if status == 0 {
            state = .completed(destination)
            return
        }
        let usefulLine = recentLines.reversed().first { line in
            !line.hasPrefix(MediaDownloadSupport.progressMarker)
                && !line.contains(MediaDownloadSupport.fileMarker)
        }
        let message = usefulLine.map { String($0.suffix(420)) }
            ?? "yt-dlp exited with status \(status)."
        state = .failed(message)
    }

    private func cancelProcess(publishCancelled: Bool) {
        operationID = nil
        if let process = activeProcess, process.isRunning {
            process.terminate()
        }
        activeProcess = nil
        if publishCancelled { state = .cancelled }
    }
}
