// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// A user-triggered, system-native internet capacity test.
///
/// macOS `networkQuality` adapts the number of flows to the connection, chooses
/// a nearby Apple endpoint and measures both throughput and responsiveness. The
/// sequential mode keeps upload traffic from depressing the download result (and
/// vice versa), which makes the two numbers comparable to an ISP plan. The tool
/// emits JSON and receives no user content; it generates test bytes only.
final class SpeedTest: ObservableObject {
    static let shared = SpeedTest()

    enum Phase: Equatable {
        case idle, latency, download, upload, done
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var latencyMs: Double?
    @Published private(set) var downloadMbps: Double?
    @Published private(set) var uploadMbps: Double?

    var isRunning: Bool {
        switch phase { case .latency, .download, .upload: return true; default: return false }
    }

    private let worker = DispatchQueue(label: "com.celikugurdev.menubench.speed-test", qos: .userInitiated)
    private let stateLock = NSLock()
    private var activeRunID: UUID?
    private var process: Process?

    private init() {}

    func start() {
        guard !isRunning else { return }
        latencyMs = nil
        downloadMbps = nil
        uploadMbps = nil
        phase = .latency

        let runID = UUID()
        stateLock.lock()
        activeRunID = runID
        stateLock.unlock()

        worker.async { [weak self] in
            self?.runSystemTest(id: runID)
        }
    }

    func cancel() {
        stateLock.lock()
        activeRunID = nil
        let runningProcess = process
        process = nil
        stateLock.unlock()

        if runningProcess?.isRunning == true {
            runningProcess?.terminate()
        }
        phase = .idle
    }

    private func runSystemTest(id: UUID) {
        let task = Process()
        let output = Pipe()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/networkQuality")
        // `-c` is machine-readable JSON, `-s` measures each direction at full
        // capacity, and the cap prevents an unhealthy network from hanging UI.
        task.arguments = ["-c", "-s", "-M", "20"]
        task.standardOutput = output
        task.standardError = FileHandle.nullDevice

        stateLock.lock()
        guard activeRunID == id else {
            stateLock.unlock()
            return
        }
        process = task
        stateLock.unlock()

        do {
            try task.run()
        } catch {
            finishFailure(error.localizedDescription, id: id)
            return
        }

        // Reading before waitUntilExit continuously drains the pipe, so a full
        // diagnostic JSON payload cannot block the child process on pipe space.
        let data = output.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        stateLock.lock()
        if activeRunID == id { process = nil }
        let stillActive = activeRunID == id
        stateLock.unlock()
        guard stillActive else { return }

        do {
            guard task.terminationReason == .exit, task.terminationStatus == 0 else {
                throw NetworkQualityOutput.ParseError.toolFailure
            }
            let result = try NetworkQualityOutput.parse(data)
            finish(result, id: id)
        } catch {
            finishFailure(error.localizedDescription, id: id)
        }
    }

    private func finish(_ result: NetworkQualityMeasurement, id: UUID) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.consume(id: id) else { return }
            self.latencyMs = result.latencyMilliseconds
            self.downloadMbps = result.downloadMegabitsPerSecond
            self.uploadMbps = result.uploadMegabitsPerSecond
            self.phase = .done
        }
    }

    private func finishFailure(_ message: String, id: UUID) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.consume(id: id) else { return }
            self.phase = .failed(message)
        }
    }

    private func consume(id: UUID) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard activeRunID == id else { return false }
        activeRunID = nil
        process = nil
        return true
    }
}
