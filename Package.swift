// swift-tools-version:5.9
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import PackageDescription

let package = Package(
    name: "Menubench",
    platforms: [.macOS(.v14)],
    targets: [
        .systemLibrary(
            name: "VMStatisticsCompat",
            path: "Sources/VMStatisticsCompat"
        ),
        .executableTarget(
            name: "Menubench",
            dependencies: ["VMStatisticsCompat"],
            path: "Sources/Menubench"
        )
    ]
)
