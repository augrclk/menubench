// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// The stable subset of macOS `networkQuality -c` output that Menubench shows.
/// Throughput is reported by the system tool in bits per second; the UI uses
/// decimal megabits per second, matching ISP plans and other speed tests.
struct NetworkQualityMeasurement: Equatable {
    let latencyMilliseconds: Double?
    let downloadMegabitsPerSecond: Double
    let uploadMegabitsPerSecond: Double
    let downloadResponsivenessRPM: Double?
    let uploadResponsivenessRPM: Double?
    let interfaceName: String?
    let endpoint: String?
}

enum NetworkQualityOutput {
    enum ParseError: Error {
        case malformedJSON
        case toolFailure
        case missingThroughput
    }

    static func parse(_ data: Data) throws -> NetworkQualityMeasurement {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let json = object as? [String: Any]
        else { throw ParseError.malformedJSON }

        if number(json["error_code"]) != nil {
            throw ParseError.toolFailure
        }
        guard let downloadBitsPerSecond = positiveNumber(json["dl_throughput"]),
              let uploadBitsPerSecond = positiveNumber(json["ul_throughput"])
        else { throw ParseError.missingThroughput }

        return NetworkQualityMeasurement(
            latencyMilliseconds: nonnegativeNumber(json["base_rtt"]),
            downloadMegabitsPerSecond: downloadBitsPerSecond / 1_000_000,
            uploadMegabitsPerSecond: uploadBitsPerSecond / 1_000_000,
            downloadResponsivenessRPM: positiveNumber(json["dl_responsiveness"]),
            uploadResponsivenessRPM: positiveNumber(json["ul_responsiveness"]),
            interfaceName: json["interface_name"] as? String,
            endpoint: json["test_endpoint"] as? String
        )
    }

    private static func number(_ value: Any?) -> Double? {
        let result: Double?
        if let value = value as? NSNumber {
            result = value.doubleValue
        } else if let value = value as? String {
            result = Double(value)
        } else {
            result = nil
        }
        guard let result, result.isFinite else { return nil }
        return result
    }

    private static func positiveNumber(_ value: Any?) -> Double? {
        guard let value = number(value), value > 0 else { return nil }
        return value
    }

    private static func nonnegativeNumber(_ value: Any?) -> Double? {
        guard let value = number(value), value >= 0 else { return nil }
        return value
    }
}
