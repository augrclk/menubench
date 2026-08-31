// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Hallmark · pre-emit critique: P5 H5 E4 S5 R5 V5

import SwiftUI

/// Hallmark · macrostructure: Workbench · tone: soft precision · anchor hue: muted coral.
/// Genre: modern-minimal / soft structuralism · enrichment: selected product artwork.
/// Shared look & feel: restrained signal colour, warm native surfaces and brand mark.
enum Theme {
    /// One signal colour. It stays on active controls, progress and focus rather
    /// than becoming a decorative background across whole views.
    static let accent = Color(red: 0.70, green: 0.20, blue: 0.14)

    static func accentWash(for scheme: ColorScheme) -> Color {
        scheme == .light
            ? Color(red: 0.97, green: 0.89, blue: 0.86)
            : Color(red: 0.31, green: 0.15, blue: 0.13)
    }

    static func warmInk(for scheme: ColorScheme) -> Color {
        scheme == .light
            ? Color(red: 0.16, green: 0.14, blue: 0.13)
            : Color(red: 0.95, green: 0.93, blue: 0.90)
    }

    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
    }

    enum Radius {
        static let control: CGFloat = 9
        static let card: CGFloat = 13
        static let shell: CGFloat = 18
    }

    /// Tonal depth for the icon and onboarding surfaces. Both stops share the
    /// same warm graphite hue; this is elevation, not an ambient colour effect.
    static let spaceGradient = LinearGradient(
        colors: [Color(red: 0.18, green: 0.15, blue: 0.14),
                 Color(red: 0.09, green: 0.075, blue: 0.07)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum PanelMetricColor {
    static func green(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color(red: 0.00, green: 0.44, blue: 0.18) : .green
    }

    static func cyan(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color(red: 0.00, green: 0.43, blue: 0.54) : .cyan
    }

    static func mint(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color(red: 0.00, green: 0.44, blue: 0.40) : .mint
    }

    static func yellow(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color(red: 0.56, green: 0.36, blue: 0.00) : .yellow
    }

    static func red(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color(red: 0.68, green: 0.08, blue: 0.10) : .red
    }

    static func orange(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color(red: 0.68, green: 0.30, blue: 0.00) : .orange
    }

    static func pink(for scheme: ColorScheme) -> Color {
        scheme == .light ? Color(red: 0.68, green: 0.06, blue: 0.34) : .pink
    }
}

enum PanelSurface {
    static func baseFill(for scheme: ColorScheme) -> Color {
        scheme == .light
            ? Color(red: 0.975, green: 0.965, blue: 0.95).opacity(0.76)
            : Color(red: 0.105, green: 0.09, blue: 0.085).opacity(0.70)
    }

    static func cardFill(for scheme: ColorScheme) -> Color {
        scheme == .light
            ? Color(red: 0.995, green: 0.985, blue: 0.97).opacity(0.82)
            : Color(red: 0.16, green: 0.135, blue: 0.125).opacity(0.72)
    }

    static func controlFill(for scheme: ColorScheme) -> Color {
        scheme == .light
            ? Color(red: 0.20, green: 0.16, blue: 0.14).opacity(0.055)
            : Color(red: 0.96, green: 0.90, blue: 0.86).opacity(0.085)
    }

    static func border(for scheme: ColorScheme) -> Color {
        scheme == .light
            ? Color(red: 0.25, green: 0.18, blue: 0.15).opacity(0.12)
            : Color(red: 0.96, green: 0.88, blue: 0.83).opacity(0.14)
    }
}

func sectionTitle(_ text: String) -> some View {
    Text(text)
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .foregroundStyle(.secondary)
}

extension View {
    /// The rounded card background used by every panel section.
    func panelCard() -> some View {
        modifier(PanelCardModifier())
    }

    /// A restrained glass base for the menu panel: still translucent, but with a
    /// stable tint so text and controls do not depend too much on the wallpaper.
    func panelGlassSurface(cornerRadius: CGFloat = 18) -> some View {
        background(PanelGlassSurface(cornerRadius: cornerRadius))
    }
}

private struct PanelCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(Theme.Space.sm)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(PanelSurface.cardFill(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(PanelSurface.border(for: colorScheme), lineWidth: 0.7)
            )
    }
}

private struct PanelGlassSurface: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage(DefaultsKey.liquidGlassEnabled) private var liquidGlassEnabled = false
    let cornerRadius: CGFloat

    var body: some View {
#if compiler(>=6.2)
        if #available(macOS 26.0, *), liquidGlassEnabled, !reduceTransparency {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.clear)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(PanelSurface.baseFill(for: colorScheme).opacity(colorScheme == .light ? 0.35 : 0.45))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(PanelSurface.border(for: colorScheme), lineWidth: 0.8)
                )
        } else {
            standardSurface
        }
#else
        standardSurface
#endif
    }

    @ViewBuilder
    private var standardSurface: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(PanelSurface.baseFill(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(PanelSurface.border(for: colorScheme), lineWidth: 0.8)
            )
    }
}

func appDelegate() -> AppDelegate? {
    NSApp.delegate as? AppDelegate
}

/// The generated Menubench mark, tintable for light or dark surfaces.
struct BrandMark: View {
    var width: CGFloat
    var tint: Color = .white

    private static let mark: NSImage? = {
        guard let url = Bundle.main.url(forResource: "BrandMark", withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }()

    var body: some View {
        if let mark = Self.mark {
            Image(nsImage: mark)
                .renderingMode(.template)
                .interpolation(.high)
                .antialiased(true)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(tint)
                .frame(width: width)
        } else {
            Image(systemName: "circle.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(tint)
                .frame(width: width * 0.5)
        }
    }
}

struct DiscordMark: View {
    var width: CGFloat

    private static let mark: NSImage? = {
        guard let url = Bundle.main.url(forResource: "discord-symbol",
                                        withExtension: "svg",
                                        subdirectory: "Images") else { return nil }
        return NSImage(contentsOf: url)
    }()

    var body: some View {
        if let mark = Self.mark {
            Image(nsImage: mark)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: width)
        }
    }
}

/// Full-colour selected artwork for product identity surfaces. Compact chrome
/// continues to use BrandMark, the template-safe silhouette derived from it.
struct BrandBadge: View {
    var size: CGFloat

    private static let artwork: NSImage? = {
        guard let url = Bundle.main.url(forResource: "MenubenchAppIcon", withExtension: "png")
        else { return nil }
        return NSImage(contentsOf: url)
    }()

    var body: some View {
        Group {
            if let artwork = Self.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .aspectRatio(contentMode: .fit)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                        .fill(Theme.spaceGradient)
                    BrandMark(width: size * 0.8)
                }
            }
        }
        .frame(width: size, height: size)
    }
}
