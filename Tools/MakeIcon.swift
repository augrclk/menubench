// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

// Generates Menubench's app icon family from the selected original artwork,
// plus a small-size template glyph derived from its folded workbench silhouette.
// No Menubench trademark asset is read or copied.
import AppKit

// Current macOS misreads PNG payloads in the legacy small chunks. It downsamples
// ic07 for 1x and uses the explicit ic11/ic12 representations on Retina displays.
let iconSizes: [(name: String, px: Int, icnsType: String?)] = [
    ("icon_16x16", 16, nil), ("icon_16x16@2x", 32, "ic11"),
    ("icon_32x32", 32, nil), ("icon_32x32@2x", 64, "ic12"),
    ("icon_128x128", 128, "ic07"), ("icon_128x128@2x", 256, "ic13"),
    ("icon_256x256", 256, "ic08"), ("icon_256x256@2x", 512, "ic14"),
    ("icon_512x512", 512, "ic09"), ("icon_512x512@2x", 1024, "ic10"),
]

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset"
let markDesignSize = CGSize(width: 512, height: 512)
let appIconSourceURL = URL(fileURLWithPath: "Resources/Brand/MenubenchAppIcon.png")
guard let appIconSource = NSImage(contentsOf: appIconSourceURL) else {
    fputs("missing Menubench app icon artwork at \(appIconSourceURL.path)\n", stderr)
    exit(1)
}

func bitmapCanvas(_ px: Int, _ py: Int) -> NSBitmapImageRep? {
    NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: py,
                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                     isPlanar: false, colorSpaceName: .deviceRGB,
                     bytesPerRow: 0, bitsPerPixel: 0)
}

/// Extract the two neutral graphite pieces from the selected full-colour
/// artwork. This keeps the compact mark faithful instead of inventing a second
/// logo, while excluding the warm porcelain shell and coral insert.
func makeTemplateMarkImage() -> (image: NSImage, sourceRect: CGRect)? {
    let side = 512
    guard let source = bitmapCanvas(side, side),
    let output = bitmapCanvas(side, side),
    let sourceContext = NSGraphicsContext(bitmapImageRep: source) else { return nil }

    source.size = markDesignSize
    output.size = markDesignSize
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = sourceContext
    sourceContext.imageInterpolation = .high
    appIconSource.draw(in: CGRect(origin: .zero, size: markDesignSize),
                       from: .zero,
                       operation: .copy,
                       fraction: 1,
                       respectFlipped: true,
                       hints: nil)
    NSGraphicsContext.restoreGraphicsState()

    guard let sourceBytes = source.bitmapData,
          let outputBytes = output.bitmapData else { return nil }
    var candidates = Array(repeating: false, count: side * side)

    for y in 0..<side {
        for x in 0..<side {
            let unitX = CGFloat(x) / CGFloat(side - 1)
            let unitY = CGFloat(y) / CGFloat(side - 1)
            let inUpperInlay = unitX >= 0.15 && unitX <= 0.62
                && unitY >= 0.14 && unitY <= 0.61
            let inLowerInlay = unitX >= 0.43 && unitX <= 0.86
                && unitY >= 0.37 && unitY <= 0.82
            guard inUpperInlay || inLowerInlay else { continue }
            let sourceOffset = y * source.bytesPerRow + x * 4
            let red = CGFloat(sourceBytes[sourceOffset]) / 255
            let green = CGFloat(sourceBytes[sourceOffset + 1]) / 255
            let blue = CGFloat(sourceBytes[sourceOffset + 2]) / 255
            let alpha = CGFloat(sourceBytes[sourceOffset + 3]) / 255
            let brightness = red * 0.299 + green * 0.587 + blue * 0.114
            let chroma = max(red, green, blue) - min(red, green, blue)
            guard alpha > 0.2, brightness < 0.76, chroma < 0.17 else {
                continue
            }
            candidates[y * side + x] = true
        }
    }

    // The two graphite inlays meet at their shaded central fold and form the
    // largest neutral connected area. Keeping it removes the ceramic rim's
    // ambient shadow and tiny transparent-edge artefacts from the master.
    var visited = Array(repeating: false, count: candidates.count)
    var components: [[Int]] = []
    for start in candidates.indices where candidates[start] && !visited[start] {
        var component: [Int] = []
        var queue = [start]
        visited[start] = true
        var cursor = 0
        while cursor < queue.count {
            let current = queue[cursor]
            cursor += 1
            component.append(current)
            let x = current % side
            let y = current / side
            let neighbours = [
                x > 0 ? current - 1 : -1,
                x + 1 < side ? current + 1 : -1,
                y > 0 ? current - side : -1,
                y + 1 < side ? current + side : -1,
            ]
            for neighbour in neighbours
                where neighbour >= 0 && candidates[neighbour] && !visited[neighbour] {
                visited[neighbour] = true
                queue.append(neighbour)
            }
        }
        components.append(component)
    }

    guard let component = components.max(by: { $0.count < $1.count }) else { return nil }
    var minX = side - 1
    var minY = side - 1
    var maxX = 0
    var maxY = 0
    for pixel in component {
        let x = pixel % side
        let y = pixel / side
        minX = min(minX, x)
        minY = min(minY, y)
        maxX = max(maxX, x)
        maxY = max(maxY, y)
        let outputOffset = y * output.bytesPerRow + x * 4
        outputBytes[outputOffset] = 255
        outputBytes[outputOffset + 1] = 255
        outputBytes[outputOffset + 2] = 255
        outputBytes[outputOffset + 3] = 255
    }

    let image = NSImage(size: markDesignSize)
    image.addRepresentation(output)
    let opticalPadding: CGFloat = 4
    let sourceRect = CGRect(x: max(0, CGFloat(minX) - opticalPadding),
                            y: max(0, CGFloat(minY) - opticalPadding),
                            width: min(CGFloat(side), CGFloat(maxX + 1) + opticalPadding)
                                - max(0, CGFloat(minX) - opticalPadding),
                            height: min(CGFloat(side), CGFloat(maxY + 1) + opticalPadding)
                                - max(0, CGFloat(minY) - opticalPadding))
    return (image, sourceRect)
}

guard let derivedTemplate = makeTemplateMarkImage() else {
    fputs("could not derive the Menubench template mark\n", stderr)
    exit(1)
}
let templateMarkImage = derivedTemplate.image
let templateMarkSourceRect = derivedTemplate.sourceRect

func drawMark(into target: CGRect, color: NSColor = .white) {
    // The derived bitmap is a white template mask. All generated resources use
    // white ink and AppKit/SwiftUI supplies the final template tint at runtime.
    _ = color
    let sourceSize = templateMarkSourceRect.size
    let scale = min(target.width / sourceSize.width, target.height / sourceSize.height)
    let fitted = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
    let rect = CGRect(x: target.midX - fitted.width / 2,
                      y: target.midY - fitted.height / 2,
                      width: fitted.width,
                      height: fitted.height)
    templateMarkImage.draw(in: rect,
                           from: templateMarkSourceRect,
                           operation: .sourceOver,
                           fraction: 1,
                           respectFlipped: true,
                           hints: nil)
}

// MARK: - App icon

func renderAppIcon(px: Int) -> Data? {
    let size = CGFloat(px)
    guard let rep = bitmapCanvas(px, px), let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    ctx.imageInterpolation = px <= 32 ? .high : .medium
    appIconSource.draw(in: CGRect(x: 0, y: 0, width: size, height: size),
                       from: .zero,
                       operation: .sourceOver,
                       fraction: 1,
                       respectFlipped: true,
                       hints: nil)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

// MARK: - Menu bar glyph (template)

// Size the square interlock from its height and center it in the wider status
// item canvas used by compact Keep Awake variants.
let menuBarGlyphHeight: CGFloat = 16.5
// The optical crop already removes the master artwork's transparent margin,
// so the mark can sit on the menu bar's natural vertical centre.
let menuBarGlyphDrop: CGFloat = 0
// Taller than the mark needs: the same canvas holds the compact Keep Awake
// symbols. Keep in sync with BlackHoleGlyph.pointSize in
// Sources/Menubench/App/StatusItemController.swift; `--selftest` enforces it.
let menuBarCanvas = (width: 26, height: 20)

func renderMenuBarIcon(scale: Int) -> Data? {
    let width = menuBarCanvas.width * scale, height = menuBarCanvas.height * scale
    guard let rep = bitmapCanvas(width, height), let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    rep.size = NSSize(width: menuBarCanvas.width, height: menuBarCanvas.height)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    // Coordinates are bottom-up, so dropping it lowers y.
    let ink = menuBarGlyphHeight * CGFloat(scale)
    let y = (CGFloat(height) - ink) / 2 - menuBarGlyphDrop * CGFloat(scale)
    drawMark(into: CGRect(x: 0, y: y, width: CGFloat(width), height: ink))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

func appendFourCC(_ value: String, to data: inout Data) {
    data.append(contentsOf: value.utf8)
}

func appendUInt32BE(_ value: Int, to data: inout Data) {
    let clamped = UInt32(value)
    data.append(UInt8((clamped >> 24) & 0xff))
    data.append(UInt8((clamped >> 16) & 0xff))
    data.append(UInt8((clamped >> 8) & 0xff))
    data.append(UInt8(clamped & 0xff))
}

func writeICNS(entries: [(type: String, data: Data)], to url: URL) throws {
    let totalLength = 8 + entries.reduce(0) { $0 + 8 + $1.data.count }
    var icns = Data()
    appendFourCC("icns", to: &icns)
    appendUInt32BE(totalLength, to: &icns)
    for entry in entries {
        appendFourCC(entry.type, to: &icns)
        appendUInt32BE(8 + entry.data.count, to: &icns)
        icns.append(entry.data)
    }
    try icns.write(to: url)
}

try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
var icnsEntries: [(type: String, data: Data)] = []
for (name, px, icnsType) in iconSizes {
    guard let data = renderAppIcon(px: px) else {
        print("failed to render \(name)")
        exit(1)
    }
    try data.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
    if let icnsType {
        icnsEntries.append((type: icnsType, data: data))
    }
}
try writeICNS(entries: icnsEntries, to: URL(fileURLWithPath: "\(outDir)/../AppIcon.icns"))

for scale in [1, 2] {
    guard let data = renderMenuBarIcon(scale: scale) else {
        print("failed to render menu bar icon @\(scale)x")
        exit(1)
    }
    let suffix = scale == 1 ? "" : "@2x"
    try data.write(to: URL(fileURLWithPath: "\(outDir)/../MenuBarIcon\(suffix).png"))
}

// Transparent mark for in-app use (panel header, onboarding, About).
let markWidth = 640
let markHeight = Int(CGFloat(markWidth) * markDesignSize.height / markDesignSize.width)
if let rep = bitmapCanvas(markWidth, markHeight), let ctx = NSGraphicsContext(bitmapImageRep: rep) {
    rep.size = NSSize(width: markWidth, height: markHeight)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    drawMark(into: CGRect(x: 0, y: 0, width: CGFloat(markWidth), height: CGFloat(markHeight)))
    NSGraphicsContext.restoreGraphicsState()
    if let data = rep.representation(using: .png, properties: [:]) {
        try data.write(to: URL(fileURLWithPath: "\(outDir)/../BrandMark.png"))
    }
}
print("iconset written to \(outDir)")
