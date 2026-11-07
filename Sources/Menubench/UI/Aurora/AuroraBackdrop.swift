// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// The panel's base: glass, a tinted plate that keeps text readable over any
/// wallpaper, and the aurora — soft light in the current area's hue drifting
/// slowly behind everything.
///
/// Reduce Transparency replaces the glass with an opaque plate; Reduce Motion
/// keeps the aurora but stops it drifting.
struct AuroraBackdrop: View {
    var hue: Aurora.Hue
    /// A second, smaller light (keep-awake running, for example).
    var accent: Aurora.Hue?
    var cornerRadius: CGFloat = Aurora.Radius.panel

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(DefaultsKey.liquidGlassEnabled) private var liquidGlassEnabled = false

    var body: some View {
        let palette = AuroraPalette(scheme)
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            base(shape: shape, palette: palette)
            AuroraGlow(hue: hue, accent: accent, strength: palette.auraStrength,
                       animated: !reduceMotion)
                .clipShape(shape)
            shape.strokeBorder(
                LinearGradient(colors: [palette.strokeLit, palette.stroke, palette.stroke.opacity(0.4)],
                               startPoint: .top, endPoint: .bottom),
                lineWidth: 0.8
            )
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func base(shape: RoundedRectangle, palette: AuroraPalette) -> some View {
        if reduceTransparency {
            shape.fill(scheme == .dark ? Color(red: 0.07, green: 0.07, blue: 0.1)
                                       : Color(red: 0.97, green: 0.97, blue: 0.985))
        } else {
#if compiler(>=6.2)
            if #available(macOS 26.0, *), liquidGlassEnabled {
                shape.fill(Color.clear)
                    .glassEffect(.regular, in: shape)
                    .overlay(shape.fill(palette.plate.opacity(0.7)))
            } else {
                shape.fill(.regularMaterial).overlay(shape.fill(palette.plate))
            }
#else
            shape.fill(.regularMaterial).overlay(shape.fill(palette.plate))
#endif
        }
    }
}

/// The drifting light. Positions come from the clock rather than from view
/// state, so a hue change cross-fades in place instead of restarting the drift.
/// Radial gradients are soft by construction, which keeps this off the blur
/// filter and cheap enough to run while the panel is open.
struct AuroraGlow: View {
    var hue: Aurora.Hue
    var accent: Aurora.Hue?
    var strength: Double
    var animated: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !animated)) { context in
            let t = animated ? context.date.timeIntervalSinceReferenceDate : 0
            GeometryReader { geo in
                ZStack {
                    ForEach([hue], id: \.self) { current in
                        lights(for: current, size: geo.size, time: t)
                            .transition(.opacity)
                    }
                    if let accent {
                        accentLight(accent, size: geo.size, time: t)
                            .transition(.opacity)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .opacity(strength)
        .animation(Aurora.Motion.hueShift, value: hue)
        .animation(Aurora.Motion.hueShift, value: accent)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func lights(for hue: Aurora.Hue, size: CGSize, time: TimeInterval) -> some View {
        let w = max(size.width, 1)
        let h = max(size.height, 1)
        // Slow, out-of-phase Lissajous drift: ~40s and ~55s periods.
        let a = time * 2 * .pi / 40
        let b = time * 2 * .pi / 55
        return ZStack {
            light(hue.primary, diameter: w * 1.25)
                .offset(x: -w * 0.30 + CGFloat(cos(a)) * w * 0.12,
                        y: -h * 0.34 + CGFloat(sin(b)) * h * 0.08)
            light(hue.secondary, diameter: w * 1.05)
                .offset(x: w * 0.34 + CGFloat(sin(a * 1.3)) * w * 0.10,
                        y: h * 0.10 + CGFloat(cos(b * 0.8)) * h * 0.10)
            light(hue.stops[hue.stops.count / 2], diameter: w * 0.8)
                .offset(x: CGFloat(cos(b * 1.7)) * w * 0.18,
                        y: h * 0.42 + CGFloat(sin(a * 0.9)) * h * 0.06)
                .opacity(0.55)
        }
    }

    private func accentLight(_ hue: Aurora.Hue, size: CGSize, time: TimeInterval) -> some View {
        let w = max(size.width, 1)
        let h = max(size.height, 1)
        let pulse = 0.85 + 0.15 * sin(time * 2 * .pi / 6)
        return light(hue.primary, diameter: w * 0.9)
            .scaleEffect(CGFloat(pulse))
            .offset(x: -w * 0.22, y: -h * 0.26)
    }

    private func light(_ color: Color, diameter: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [color.opacity(0.85), color.opacity(0.32), color.opacity(0)],
                                 center: .center, startRadius: 0, endRadius: diameter / 2))
            .frame(width: diameter, height: diameter)
    }
}
