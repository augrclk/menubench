// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

// MARK: - Hues for Settings

extension SettingsPage {
    /// Each page wears the hue of the area it configures, the same colour the
    /// panel gives that area, so a page and its tile are recognisably one.
    var auroraHue: Aurora.Hue {
        switch self {
        case .general, .advanced, .about, .commandBar: return .neutral
        case .features: return .tools
        case .energy: return .power
        case .monitor: return .cpu
        case .mouse, .keyDebounce, .superKey, .shortcuts: return .controls
        case .switcher, .windowLayout: return .night
        case .cutPaste, .clipboard, .appUpdates, .quickTools: return .tools
        case .autoQuit: return .toggles
        case .cleaner: return .memory
        case .uninstaller, .killProcess, .support: return .sound
        case .urlCleaner, .screenshot: return .network
        case .homebrew: return .power
        case .media, .radialMenu: return .gpu
        case .shelf, .textSnippets: return .disk
        case .releaseNotes: return .sunrise
        }
    }

    /// Pages that already open with a header of their own.
    var drawsOwnHeader: Bool { self == .media }
}

extension FeatureGroup {
    var auroraHue: Aurora.Hue {
        switch self {
        case .windowsDock: return .night
        case .mouseKeyboard: return .controls
        case .clipboardFiles: return .tools
        case .sound: return .sound
        case .energyDisplay: return .power
        case .tools: return .disk
        case .monitor: return .cpu
        }
    }
}

extension FeaturePreset {
    var auroraHue: Aurora.Hue {
        switch self {
        case .essential: return .neutral
        case .windows: return .night
        case .battery: return .power
        }
    }
}

// MARK: - Sidebar icon

/// The sidebar's page icon: a small rounded square in the page's gradient,
/// the way System Settings marks its panes.
struct SettingsSidebarIcon: View {
    let systemImage: String
    let hue: Aurora.Hue

    var body: some View {
        RoundedRectangle(cornerRadius: 5.5, style: .continuous)
            .fill(hue.gradient)
            .overlay(
                RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.28), Color.clear],
                                         startPoint: .top, endPoint: .center))
            )
            .overlay(
                Image(systemName: systemImage)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: 0.5, y: 0.5)
            )
            .frame(width: 20, height: 20)
            .accessibilityHidden(true)
    }
}

// MARK: - Page chrome

/// Frames every Settings page: the aurora of its hue glowing from the top,
/// a header with the page's badge and name, and a short cross-fade with a
/// little rise when the page changes.
struct SettingsPageChrome<Content: View>: View {
    let page: SettingsPage
    let title: String
    let symbol: String
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack(alignment: .top) {
            if !reduceTransparency {
                AuroraGlow(hue: page.auroraHue, accent: nil,
                           strength: scheme == .dark ? 0.34 : 0.26,
                           animated: !reduceMotion)
                    .frame(height: 340)
                    .mask(LinearGradient(colors: [.black, .black.opacity(0.6), .clear],
                                         startPoint: .top, endPoint: .bottom))
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
            }

            VStack(alignment: .leading, spacing: 0) {
                if !page.drawsOwnHeader {
                    header
                        .padding(.horizontal, 24)
                        .padding(.top, 14)
                        .padding(.bottom, 2)
                }
                content()
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .id(page)
            .transition(reduceMotion ? .opacity : .settingsPage)
        }
        .animation(reduceMotion ? Aurora.Motion.reduced : .spring(response: 0.38, dampingFraction: 0.9),
                   value: page)
    }

    private var header: some View {
        HStack(spacing: 12) {
            AuroraHueBadge(systemImage: symbol, hue: page.auroraHue, size: 34)
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

private struct SettingsPageTransitionModifier: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        content
            .opacity(active ? 0 : 1)
            .offset(y: active ? 10 : 0)
            .blur(radius: active ? 4 : 0)
    }
}

extension AnyTransition {
    /// The incoming page rises a few points out of a light blur; the outgoing
    /// page simply fades, so the two never visibly collide.
    static var settingsPage: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: SettingsPageTransitionModifier(active: true),
                                 identity: SettingsPageTransitionModifier(active: false)),
            removal: .opacity.animation(.easeOut(duration: 0.12))
        )
    }
}

// MARK: - Preset card

/// A one-click feature set: badge, name, what it turns on, and Apply.
struct AuroraPresetCard: View {
    let preset: FeaturePreset
    let name: String
    let caption: String
    let applyTitle: String
    let onApply: () -> Void

    @State private var hovered = false
    @State private var hoverPoint: CGPoint?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AuroraHueBadge(systemImage: preset.symbolName, hue: preset.auroraHue, size: 26)
                Text(name)
                    .font(Aurora.Font.headline)
                    .lineLimit(1)
            }
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            Button(applyTitle, action: onApply)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
        .background(AuroraTileSurface(hue: preset.auroraHue, isHovered: hovered,
                                      hoverPoint: hoverPoint, cornerRadius: 14))
        .scaleEffect(hovered && !reduceMotion ? 1.015 : 1)
        .animation(Aurora.Motion.resolve(Aurora.Motion.bouncy, reduceMotion: reduceMotion), value: hovered)
        .onContinuousHover { phase in
            switch phase {
            case .active(let point):
                hoverPoint = point
                if !hovered { hovered = true }
            case .ended:
                hovered = false
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name). \(caption)")
    }
}
