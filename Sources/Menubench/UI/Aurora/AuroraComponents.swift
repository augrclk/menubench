// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

// MARK: - Tile surface

/// The glass of a tile or card. A light rim on the top edge, an optional wash
/// of the area's hue, a full gradient when the tile is "on", and a soft light
/// that follows the pointer while it hovers.
struct AuroraTileSurface: View {
    var hue: Aurora.Hue?
    var filled = false
    var isHovered = false
    var isPressed = false
    var hoverPoint: CGPoint?
    var cornerRadius: CGFloat = Aurora.Radius.tile

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = AuroraPalette(scheme)
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            shape.fill(isPressed ? palette.tilePressed : (isHovered ? palette.tileHover : palette.tile))

            if let hue, !filled {
                shape.fill(hue.gradient).opacity(scheme == .dark ? 0.10 : 0.12)
            }

            if let hue, filled {
                shape.fill(hue.gradient)
                // Depth inside the gradient: lighter at the top, a touch of
                // shade at the bottom, the way lit glass reads.
                shape.fill(LinearGradient(colors: [Color.white.opacity(0.22), Color.clear, Color.black.opacity(0.12)],
                                          startPoint: .top, endPoint: .bottom))
            }

            if isHovered, let hoverPoint {
                GeometryReader { geo in
                    RadialGradient(colors: [Color.white.opacity(scheme == .dark ? 0.16 : 0.55), Color.white.opacity(0)],
                                   center: UnitPoint(x: hoverPoint.x / max(geo.size.width, 1),
                                                     y: hoverPoint.y / max(geo.size.height, 1)),
                                   startRadius: 0, endRadius: 110)
                }
                .clipShape(shape)
                .blendMode(scheme == .dark ? .plusLighter : .normal)
                .transition(.opacity)
            }

            shape.strokeBorder(
                LinearGradient(colors: filled
                                   ? [Color.white.opacity(0.55), Color.white.opacity(0.12)]
                                   : [palette.strokeLit, palette.stroke],
                               startPoint: .top, endPoint: .bottom),
                lineWidth: 0.7
            )
        }
        .compositingGroup()
        .shadow(color: filled ? (hue?.primary ?? .clear).opacity(palette.glowStrength * 0.8) : .clear,
                radius: filled ? 14 : 0, y: filled ? 4 : 0)
    }
}

// MARK: - Tile button

/// A pressable tile: lifts a little under the pointer, sinks when pressed.
struct AuroraTileButtonStyle: ButtonStyle {
    var hue: Aurora.Hue?
    var filled = false
    var padding: CGFloat = 11
    var cornerRadius: CGFloat = Aurora.Radius.tile

    func makeBody(configuration: Configuration) -> some View {
        AuroraTileButtonBody(configuration: configuration, hue: hue, filled: filled,
                             padding: padding, cornerRadius: cornerRadius)
    }
}

private struct AuroraTileButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let hue: Aurora.Hue?
    let filled: Bool
    let padding: CGFloat
    let cornerRadius: CGFloat

    @State private var hovered = false
    @State private var hoverPoint: CGPoint?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(padding)
            // Edge-to-edge content (a chart along the bottom, a light sweep)
            // follows the tile's rounded corners.
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(
                AuroraTileSurface(hue: hue, filled: filled, isHovered: hovered,
                                  isPressed: configuration.isPressed, hoverPoint: hoverPoint,
                                  cornerRadius: cornerRadius)
            )
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.955 : (hovered ? 1.018 : 1)))
            .animation(Aurora.Motion.resolve(Aurora.Motion.snappy, reduceMotion: reduceMotion),
                       value: configuration.isPressed)
            .animation(Aurora.Motion.resolve(Aurora.Motion.bouncy, reduceMotion: reduceMotion), value: hovered)
            .animation(Aurora.Motion.smooth, value: filled)
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    hoverPoint = point
                    if !hovered { hovered = true }
                case .ended:
                    hovered = false
                }
            }
    }
}

/// The same glass for a tile that hosts its own controls (a slider) and so
/// cannot be one big button.
struct AuroraTileContainer<Content: View>: View {
    var hue: Aurora.Hue?
    var padding: CGFloat = 10
    @ViewBuilder var content: () -> Content

    @State private var hovered = false
    @State private var hoverPoint: CGPoint?

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(padding)
            .background(AuroraTileSurface(hue: hue, isHovered: hovered, hoverPoint: hoverPoint))
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    hoverPoint = point
                    if !hovered { hovered = true }
                case .ended:
                    hovered = false
                }
            }
            .animation(Aurora.Motion.snappy, value: hovered)
    }
}

// MARK: - Card

/// Glass card for content inside a detail page. Replaces the old flat card;
/// existing sections reach it through `panelCard()`.
struct AuroraCardSurface: View {
    var cornerRadius: CGFloat = Aurora.Radius.card
    @Environment(\.colorScheme) private var scheme
    @Environment(\.auroraHue) private var hue

    var body: some View {
        let palette = AuroraPalette(scheme)
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            shape.fill(palette.tile)
            shape.fill(hue.gradient).opacity(scheme == .dark ? 0.045 : 0.05)
            shape.strokeBorder(LinearGradient(colors: [palette.strokeLit, palette.stroke],
                                              startPoint: .top, endPoint: .bottom),
                               lineWidth: 0.7)
        }
    }
}

// MARK: - Ring

/// A gauge ring: a quiet track and a gradient arc with a soft glow of its own
/// colour. The arc eases to each new reading.
struct AuroraRing<Center: View>: View {
    var progress: Double
    var hue: Aurora.Hue
    var lineWidth: CGFloat = 6
    @ViewBuilder var center: () -> Center

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let palette = AuroraPalette(scheme)
        let value = min(max(progress.isFinite ? progress : 0, 0), 1)
        ZStack {
            Circle().stroke(palette.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(value, 0.002))
                .stroke(hue.angular, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: hue.primary.opacity(palette.glowStrength), radius: lineWidth * 0.8)
            center()
        }
        .padding(lineWidth / 2)
        .animation(reduceMotion ? nil : Aurora.Motion.reading, value: value)
    }
}

extension AuroraRing where Center == EmptyView {
    init(progress: Double, hue: Aurora.Hue, lineWidth: CGFloat = 6) {
        self.init(progress: progress, hue: hue, lineWidth: lineWidth) { EmptyView() }
    }
}

// MARK: - Sparkline

/// A live history line: smoothed, filled with a fading wash of its hue, and
/// morphing between readings instead of jumping.
struct AuroraSparkline: View {
    var values: [Double]
    /// The value that reaches the top. `nil` scales to the largest reading.
    var ceiling: Double?
    var hue: Aurora.Hue
    var lineWidth: CGFloat = 1.6
    var fillOpacity: Double = 0.38
    /// The line always holds this many points. While history is still
    /// filling, the missing oldest points repeat the first reading, so the
    /// point count never changes and every update can morph smoothly.
    var sampleCount = 36

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let normalized = Self.normalize(Self.fixedLength(values, count: sampleCount), ceiling: ceiling)
        let palette = AuroraPalette(scheme)
        ZStack {
            SparklineShape(samples: AnimatableSamples(normalized), closed: true)
                .fill(LinearGradient(colors: [hue.primary.opacity(fillOpacity), hue.primary.opacity(0)],
                                     startPoint: .top, endPoint: .bottom))
            SparklineShape(samples: AnimatableSamples(normalized), closed: false)
                .stroke(hue.horizontalGradient,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
                .shadow(color: hue.primary.opacity(palette.glowStrength), radius: 3)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: normalized)
        .accessibilityHidden(true)
    }

    static func fixedLength(_ values: [Double], count: Int) -> [Double] {
        let recent = Array(values.suffix(count))
        guard recent.count < count else { return recent }
        return Array(repeating: recent.first ?? 0, count: count - recent.count) + recent
    }

    static func normalize(_ values: [Double], ceiling: Double?) -> [Double] {
        let clean = values.map { $0.isFinite ? max($0, 0) : 0 }
        guard !clean.isEmpty else { return [] }
        let top = max(ceiling ?? (clean.max() ?? 1), 0.000_001)
        return clean.map { min($0 / top, 1) }
    }
}

/// `[Double]` as a vector SwiftUI can interpolate. Differently sized arrays
/// (the first few samples) snap instead of interpolating.
struct AnimatableSamples: VectorArithmetic, Equatable {
    var values: [Double]

    init(_ values: [Double]) { self.values = values }

    static var zero: AnimatableSamples { AnimatableSamples([]) }

    static func + (lhs: AnimatableSamples, rhs: AnimatableSamples) -> AnimatableSamples {
        combine(lhs, rhs, +)
    }

    static func - (lhs: AnimatableSamples, rhs: AnimatableSamples) -> AnimatableSamples {
        combine(lhs, rhs, -)
    }

    mutating func scale(by rhs: Double) {
        values = values.map { $0 * rhs }
    }

    var magnitudeSquared: Double { values.reduce(0) { $0 + $1 * $1 } }

    private static func combine(_ lhs: AnimatableSamples, _ rhs: AnimatableSamples,
                                _ op: (Double, Double) -> Double) -> AnimatableSamples {
        if lhs.values.isEmpty { return rhs.values.isEmpty ? lhs : AnimatableSamples(rhs.values.map { op(0, $0) }) }
        if rhs.values.isEmpty { return lhs }
        guard lhs.values.count == rhs.values.count else { return rhs }
        return AnimatableSamples(zip(lhs.values, rhs.values).map(op))
    }
}

struct SparklineShape: Shape {
    var samples: AnimatableSamples
    var closed: Bool

    var animatableData: AnimatableSamples {
        get { samples }
        set { samples = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let values = samples.values
        var path = Path()
        guard values.count > 1 else { return path }
        let inset: CGFloat = 2
        let usable = max(rect.height - inset * 2, 1)
        let step = rect.width / CGFloat(values.count - 1)
        let points = values.enumerated().map { index, value in
            CGPoint(x: rect.minX + CGFloat(index) * step,
                    y: rect.maxY - inset - CGFloat(value) * usable)
        }

        path.move(to: points[0])
        // Catmull-Rom through every sample, converted to cubic Béziers, with
        // control points clamped to the chart so peaks never overshoot it.
        for i in 0..<(points.count - 1) {
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(i + 2, points.count - 1)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6,
                             y: min(max(p1.y + (p2.y - p0.y) / 6, rect.minY), rect.maxY))
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6,
                             y: min(max(p2.y - (p3.y - p1.y) / 6, rect.minY), rect.maxY))
            path.addCurve(to: p2, control1: c1, control2: c2)
        }

        if closed {
            path.addLine(to: CGPoint(x: points[points.count - 1].x, y: rect.maxY))
            path.addLine(to: CGPoint(x: points[0].x, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

// MARK: - Numbers

/// A live reading whose digits roll to the next value.
struct AuroraNumber: View {
    var value: Double
    var text: String
    var font: Font = Aurora.Font.metric

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(text)
            .font(font)
            .monospacedDigit()
            .contentTransition(reduceMotion ? .opacity : .numericText(value: value))
            .animation(reduceMotion ? nil : Aurora.Motion.snappy, value: value)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

// MARK: - Capsule slider

/// A Control Center-style level: drag anywhere along it. The fill is the
/// area's gradient; the capsule swells slightly while it is being dragged.
struct AuroraCapsuleSlider: View {
    @Binding var value: Double
    var hue: Aurora.Hue
    var symbol: (Double) -> String
    var accessibilityLabel: String
    var height: CGFloat = 34
    var onCommit: (Double) -> Void = { _ in }

    @State private var dragging = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let palette = AuroraPalette(scheme)
        let level = min(max(value.isFinite ? value : 0, 0), 1)
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            ZStack(alignment: .leading) {
                Capsule().fill(palette.well)
                Capsule()
                    .fill(hue.horizontalGradient)
                    .frame(width: max(height, width * level))
                    .shadow(color: hue.primary.opacity(palette.glowStrength * 0.7), radius: dragging ? 10 : 5)
                Image(systemName: symbol(level))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: height)
                    .shadow(color: .black.opacity(0.25), radius: 2)
            }
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(palette.stroke, lineWidth: 0.7))
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        if !dragging { dragging = true }
                        value = min(max(drag.location.x / width, 0), 1)
                    }
                    .onEnded { drag in
                        dragging = false
                        onCommit(min(max(drag.location.x / width, 0), 1))
                    }
            )
        }
        .frame(height: height)
        .scaleEffect(x: 1, y: dragging && !reduceMotion ? 1.1 : 1)
        .animation(Aurora.Motion.resolve(Aurora.Motion.bouncy, reduceMotion: reduceMotion), value: dragging)
        .animation(dragging ? nil : Aurora.Motion.snappy, value: level)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue("\(Int((level * 100).rounded())) %")
        .accessibilityAdjustableAction { direction in
            let step = 0.0625
            let next = direction == .increment ? level + step : level - step
            value = min(max(next, 0), 1)
            onCommit(value)
        }
    }
}

// MARK: - Icon button

/// A round glass button for the panel's chrome (back, settings, quit).
struct AuroraIconButton: View {
    let systemImage: String
    var help: String
    var size: CGFloat = 28
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.43, weight: .semibold))
                .frame(width: size, height: size)
        }
        .buttonStyle(AuroraCircleButtonStyle())
        .help(help)
        .accessibilityLabel(help)
    }
}

struct AuroraCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        AuroraCircleButtonBody(configuration: configuration)
    }
}

private struct AuroraCircleButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @State private var hovered = false
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let palette = AuroraPalette(scheme)
        configuration.label
            .foregroundStyle(hovered ? Color.primary : palette.secondaryText)
            .background(Circle().fill(hovered ? palette.tileHover : palette.tile))
            .overlay(Circle().strokeBorder(LinearGradient(colors: [palette.strokeLit, palette.stroke],
                                                          startPoint: .top, endPoint: .bottom),
                                           lineWidth: 0.7))
            .contentShape(Circle())
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.86 : (hovered ? 1.06 : 1)))
            .animation(Aurora.Motion.resolve(Aurora.Motion.bouncy, reduceMotion: reduceMotion),
                       value: configuration.isPressed)
            .animation(Aurora.Motion.snappy, value: hovered)
            .onHover { hovered = $0 }
    }
}

// MARK: - Hue badge

/// A small rounded square filled with the area's gradient, holding its symbol.
struct AuroraHueBadge: View {
    let systemImage: String
    let hue: Aurora.Hue
    var size: CGFloat = 26

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
            .fill(hue.gradient)
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.3), Color.clear],
                                         startPoint: .top, endPoint: .center))
            )
            .overlay(
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.48, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 1, y: 0.5)
            )
            .frame(width: size, height: size)
            .shadow(color: hue.primary.opacity(0.35), radius: 6, y: 2)
    }
}

// MARK: - Entrance

/// Tiles arrive one after another when the panel opens: up a few points, out
/// of a slight blur, settling on a spring.
struct AuroraEntrance: ViewModifier {
    let index: Int
    let visible: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let travel = !visible && !reduceMotion
        content
            .opacity(visible ? 1 : 0)
            .scaleEffect(travel ? 0.94 : 1)
            .offset(y: travel ? 12 : 0)
            .blur(radius: travel ? 6 : 0)
            .animation(visible
                       ? Aurora.Motion.resolve(Aurora.Motion.bouncy, reduceMotion: reduceMotion)
                           .delay(reduceMotion ? 0 : Aurora.Motion.stagger(index))
                       : nil,
                       value: visible)
    }
}

extension View {
    func auroraEntrance(_ index: Int, visible: Bool) -> some View {
        modifier(AuroraEntrance(index: index, visible: visible))
    }
}
