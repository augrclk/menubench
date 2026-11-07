// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Aurora: Menubench's visual language.
///
/// Dark glass, one hue per area of the Mac, and light that moves slowly behind
/// it. Every surface, number and control in the menu panel takes its colour,
/// size, corner and motion from here, so the panel reads as one object instead
/// of a stack of unrelated cards.
enum Aurora {

    // MARK: Hues

    /// Each area of the panel owns a two-stop hue. The first stop leads (rings,
    /// icons, tints); the second gives gradients their direction.
    enum Hue: String, CaseIterable, Hashable {
        case night, sunrise, cpu, gpu, memory, power, network, disk, sound, brightness, fan,
             tools, controls, toggles, neutral

        var stops: [Color] {
            switch self {
            case .night: return [Color(hex: 0x7D7AFF), Color(hex: 0x5E5CE6)]
            case .sunrise: return [Color(hex: 0xFFB347), Color(hex: 0xFF6B6B), Color(hex: 0xE8508A)]
            case .cpu: return [Color(hex: 0x64D2FF), Color(hex: 0xBF5AF2)]
            case .gpu: return [Color(hex: 0xBF5AF2), Color(hex: 0xFF5E8A)]
            case .memory: return [Color(hex: 0x30D158), Color(hex: 0x63E6BE)]
            case .power: return [Color(hex: 0xFFD60A), Color(hex: 0xFF9F0A)]
            case .network: return [Color(hex: 0x32D4C8), Color(hex: 0x64D2FF)]
            case .disk: return [Color(hex: 0xA78BFA), Color(hex: 0x5E5CE6)]
            case .sound: return [Color(hex: 0xFF5E8A), Color(hex: 0xFF9F0A)]
            case .brightness: return [Color(hex: 0xFFD60A), Color(hex: 0xFFE98A)]
            case .fan: return [Color(hex: 0x5AC8FA), Color(hex: 0x64D2FF)]
            case .tools: return [Color(hex: 0x64D2FF), Color(hex: 0x7D7AFF)]
            case .controls: return [Color(hex: 0x63E6BE), Color(hex: 0x32D4C8)]
            case .toggles: return [Color(hex: 0xFF9F0A), Color(hex: 0xFF5E8A)]
            case .neutral: return [Color(hex: 0x8E8EF5), Color(hex: 0x64D2FF)]
            }
        }

        var primary: Color { stops[0] }
        var secondary: Color { stops[stops.count - 1] }

        /// The lead colour, deepened in light mode so it holds 4.5:1 as text
        /// and as a thin stroke on a pale tile.
        func ink(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? primary : primary.mix(with: .black, by: 0.38)
        }

        /// For `.tint`: deep enough that white text on a prominent button
        /// stays legible, which the bright lead stops alone are not.
        func controlTint(_ scheme: ColorScheme) -> Color {
            primary.mix(with: .black, by: scheme == .dark ? 0.3 : 0.38)
        }

        var gradient: LinearGradient {
            LinearGradient(colors: stops, startPoint: .topLeading, endPoint: .bottomTrailing)
        }

        var horizontalGradient: LinearGradient {
            LinearGradient(colors: stops, startPoint: .leading, endPoint: .trailing)
        }

        /// Ring fill: sweeps through the stops and back, so a nearly full ring
        /// does not show a hard seam where the end meets the start. Starts at
        /// three o'clock like `Circle().trim`; rings rotate both by -90°.
        var angular: AngularGradient {
            AngularGradient(colors: stops + [stops[0]], center: .center,
                            startAngle: .degrees(0), endAngle: .degrees(360))
        }

        static func forSection(_ id: PanelSectionID) -> Hue {
            switch id {
            case .keepAwake: return .night
            case .brightness: return .brightness
            case .mixer: return .sound
            case .system: return .cpu
            case .network: return .network
            case .disk: return .disk
            case .power: return .power
            case .fanControl: return .fan
            case .utilities: return .tools
            case .controls: return .controls
            case .toggles: return .toggles
            }
        }

        static func forMetric(_ kind: MetricDetailKind) -> Hue {
            switch kind {
            case .cpu: return .cpu
            case .gpu: return .gpu
            case .memory: return .memory
            case .network: return .network
            case .disk: return .disk
            case .battery, .power: return .power
            case .fan: return .fan
            }
        }
    }

    // MARK: Metrics

    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 6
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }

    enum Radius {
        static let chip: CGFloat = 8
        static let control: CGFloat = 11
        static let card: CGFloat = 16
        static let tile: CGFloat = 18
        static let panel: CGFloat = 22
    }

    /// The panel's measurements. The content column stays 308pt wide because
    /// every existing section was laid out for it.
    enum Panel {
        static let width: CGFloat = 332
        static let padding: CGFloat = 12
        static let contentWidth: CGFloat = width - padding * 2
        static let bentoColumns = 4
        static let bentoSpacing: CGFloat = 8
        static let bentoRow: CGFloat = 72
    }

    // MARK: Type

    /// A short, rounded type scale. Numbers use monospaced digits so live
    /// readings do not jitter sideways as they change.
    enum Font {
        static let hero = SwiftUI.Font.system(size: 30, weight: .bold, design: .rounded)
        static let metric = SwiftUI.Font.system(size: 22, weight: .semibold, design: .rounded)
        static let metricSmall = SwiftUI.Font.system(size: 15, weight: .semibold, design: .rounded)
        static let title = SwiftUI.Font.system(size: 17, weight: .bold, design: .rounded)
        static let headline = SwiftUI.Font.system(size: 13, weight: .semibold, design: .rounded)
        static let body = SwiftUI.Font.system(size: 12.5, weight: .regular)
        static let label = SwiftUI.Font.system(size: 11, weight: .medium, design: .rounded)
        static let caption = SwiftUI.Font.system(size: 10.5, weight: .regular)
        static let micro = SwiftUI.Font.system(size: 10, weight: .semibold, design: .rounded)
    }

    // MARK: Motion

    /// Three springs cover the panel. Reduce Motion swaps each for a short
    /// fade-speed ease, so nothing bounces or travels for those users.
    enum Motion {
        static let snappy = Animation.spring(response: 0.3, dampingFraction: 0.78)
        static let bouncy = Animation.spring(response: 0.46, dampingFraction: 0.66)
        static let smooth = Animation.spring(response: 0.55, dampingFraction: 0.9)
        static let reading = Animation.easeOut(duration: 0.6)
        static let hueShift = Animation.easeInOut(duration: 0.9)
        static let reduced = Animation.easeInOut(duration: 0.18)

        static func stagger(_ index: Int) -> Double { min(Double(index) * 0.028, 0.34) }

        static func resolve(_ animation: Animation, reduceMotion: Bool) -> Animation {
            reduceMotion ? reduced : animation
        }
    }
}

// MARK: - Palette

/// Surface colours for the current appearance. Dark is the signature look;
/// light keeps the same structure as frosted white with a softer aura.
struct AuroraPalette {
    let scheme: ColorScheme

    init(_ scheme: ColorScheme) { self.scheme = scheme }

    private var dark: Bool { scheme == .dark }

    /// Laid over the material so text never depends on the wallpaper.
    var plate: Color {
        dark ? Color(red: 0.045, green: 0.045, blue: 0.075).opacity(0.74)
             : Color(red: 0.975, green: 0.975, blue: 0.99).opacity(0.62)
    }

    var tile: Color { dark ? Color.white.opacity(0.075) : Color.white.opacity(0.66) }
    var tileHover: Color { dark ? Color.white.opacity(0.12) : Color.white.opacity(0.86) }
    var tilePressed: Color { dark ? Color.white.opacity(0.16) : Color.white.opacity(0.95) }
    var well: Color { dark ? Color.black.opacity(0.22) : Color.black.opacity(0.045) }
    var track: Color { dark ? Color.white.opacity(0.09) : Color.black.opacity(0.075) }
    var stroke: Color { dark ? Color.white.opacity(0.10) : Color.black.opacity(0.07) }
    var strokeLit: Color { dark ? Color.white.opacity(0.24) : Color.white.opacity(0.95) }
    var divider: Color { dark ? Color.white.opacity(0.08) : Color.black.opacity(0.07) }
    var secondaryText: Color { dark ? Color.white.opacity(0.62) : Color.black.opacity(0.56) }
    var tertiaryText: Color { dark ? Color.white.opacity(0.40) : Color.black.opacity(0.38) }
    var auraStrength: Double { dark ? 0.62 : 0.42 }
    var glowStrength: Double { dark ? 0.55 : 0.22 }
}

// MARK: - Colour helpers

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    /// Linear blend in sRGB. `Color.mix(with:by:)` only exists from macOS 15,
    /// and the panel still supports 14.
    func mix(with other: Color, by fraction: Double) -> Color {
        let a = NSColor(self).usingColorSpace(.sRGB) ?? .gray
        let b = NSColor(other).usingColorSpace(.sRGB) ?? .gray
        let t = CGFloat(min(max(fraction, 0), 1))
        return Color(.sRGB,
                     red: Double(a.redComponent + (b.redComponent - a.redComponent) * t),
                     green: Double(a.greenComponent + (b.greenComponent - a.greenComponent) * t),
                     blue: Double(a.blueComponent + (b.blueComponent - a.blueComponent) * t),
                     opacity: Double(a.alphaComponent + (b.alphaComponent - a.alphaComponent) * t))
    }
}

// MARK: - Environment

private struct AuroraHueKey: EnvironmentKey {
    static let defaultValue: Aurora.Hue = .neutral
}

private struct PanelSectionTitleHiddenKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// The hue of the panel area a view sits in; detail pages set it so the
    /// shared cards and controls inside an existing section pick it up.
    var auroraHue: Aurora.Hue {
        get { self[AuroraHueKey.self] }
        set { self[AuroraHueKey.self] = newValue }
    }

    /// The detail page draws the section's title in its own header, so the
    /// section's built-in title row steps aside (its edit controls stay).
    var panelSectionTitleHidden: Bool {
        get { self[PanelSectionTitleHiddenKey.self] }
        set { self[PanelSectionTitleHiddenKey.self] = newValue }
    }
}
