// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

// MARK: - Keep awake

/// The panel's one big switch. Off, it is night glass with a moon; on, the
/// tile becomes a sunrise, the moon turns to a sun and a slow light sweeps it.
/// The whole tile toggles; the corner chevron opens the full controls.
struct KeepAwakeTile: View {
    var openDetail: () -> Void

    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var awake = KeepAwakeManager.shared
    @State private var flips = 0
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let on = awake.isActive
        ZStack(alignment: .topTrailing) {
            Button {
                awake.toggle()
                flips += 1
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(on ? Color.white : AuroraPalette(scheme).well)
                            .shadow(color: on ? Color.white.opacity(0.75) : .clear, radius: on ? 16 : 0)
                        Image(systemName: on ? "sun.max.fill" : "moon.zzz.fill")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(on ? AnyShapeStyle(Aurora.Hue.sunrise.gradient)
                                                : AnyShapeStyle(Aurora.Hue.night.gradient))
                            .contentTransition(.symbolEffect(.replace.downUp))
                            .symbolEffect(.bounce, value: flips)
                            .rotationEffect(.degrees(on && !reduceMotion ? 0 : -12))
                    }
                    .frame(width: 44, height: 44)

                    Spacer(minLength: 6)

                    Text(l10n.s.keepAwakeTitle)
                        .font(Aurora.Font.headline)
                        .foregroundStyle(on ? Color.white : Color.primary)
                        .lineLimit(1)
                    status
                        .font(Aurora.Font.caption)
                        .foregroundStyle(on ? Color.white.opacity(0.85) : AuroraPalette(scheme).secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .overlay { if on && !reduceMotion { ShimmerSweep() } }
            }
            .buttonStyle(AuroraTileButtonStyle(hue: on ? .sunrise : .night, filled: on))
            .accessibilityLabel(l10n.s.keepAwakeTitle)
            .accessibilityValue(on ? l10n.s.keepAwakeUntilDisabled : l10n.s.keepAwakeNormalRules)
            .accessibilityAddTraits(on ? .isSelected : [])

            Button(action: openDetail) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9.5, weight: .bold))
                    .frame(width: 22, height: 22)
                    .foregroundStyle(on ? Color.white : AuroraPalette(scheme).secondaryText)
                    .background(Circle().fill(on ? Color.white.opacity(0.22) : AuroraPalette(scheme).well))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(9)
            .help(l10n.s.keepAwakeOptions)
            .accessibilityLabel(l10n.s.keepAwakeOptions)
        }
        .animation(Aurora.Motion.resolve(Aurora.Motion.bouncy, reduceMotion: reduceMotion), value: on)
    }

    @ViewBuilder
    private var status: some View {
        if awake.isActive {
            if awake.sessionTrigger == .automation {
                Text(FeatureStrings.keepAwakeAutomation(l10n.language)
                    .activeStatus(for: awake.activeAutomationConditions))
            } else if let end = awake.endDate {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(Self.remaining(until: end))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                }
            } else {
                Text(l10n.s.keepAwakeUntilDisabled)
            }
        } else {
            Text(l10n.s.keepAwakeNormalRules)
        }
    }

    static func remaining(until end: Date) -> String {
        let total = max(0, Int(end.timeIntervalSinceNow))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

/// A band of light that crosses a lit tile every few seconds.
private struct ShimmerSweep: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            LinearGradient(colors: [.clear, Color.white.opacity(0.32), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: w * 0.45)
                .rotationEffect(.degrees(18))
                .frame(maxHeight: .infinity)
                .phaseAnimator([false, true]) { band, crossed in
                    band.offset(x: crossed ? w * 1.4 : -w * 0.9)
                } animation: { crossed in
                    crossed ? .easeInOut(duration: 1.3).delay(2.6) : .linear(duration: 0)
                }
        }
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - CPU

struct CPUTile: View {
    var open: () -> Void

    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var monitor = SystemMonitor.shared
    @AppStorage(DefaultsKey.temperatureUnit) private var temperatureUnit = TemperatureUnit.celsius.rawValue
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let snapshot = monitor.snapshot
        let cpu = snapshot.cpuUsage ?? 0
        Button(action: open) {
            ZStack(alignment: .bottom) {
                // The ceiling follows recent peaks (never below 25%), so an
                // idle Mac still shows its rhythm; the number states the level.
                AuroraSparkline(values: snapshot.cpuHistory,
                                ceiling: min(max((snapshot.cpuHistory.suffix(36).max() ?? 0) * 1.25, 0.25), 1),
                                hue: .cpu,
                                lineWidth: 1.8, fillOpacity: 0.45)
                    .frame(height: 62)
                    .padding(.horizontal, -11)
                    .padding(.bottom, -11)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Image(systemName: "cpu").font(.system(size: 10.5, weight: .semibold))
                        Text(l10n.s.cpuLabel).font(Aurora.Font.label)
                        Spacer(minLength: 0)
                        if let temp = snapshot.cpuTemperature {
                            Text(MetricFormat.temperatureCompact(temp, unit: unit))
                                .font(Aurora.Font.micro)
                                .monospacedDigit()
                        }
                    }
                    .foregroundStyle(AuroraPalette(scheme).secondaryText)

                    AuroraNumber(value: cpu * 100, text: snapshot.cpuUsage.map { MetricFormat.percent($0) } ?? "–",
                                 font: Aurora.Font.hero)

                    if let gpu = snapshot.gpuUsage, AppFeature.monitorGPU.isAvailable {
                        HStack(spacing: 4) {
                            Text(l10n.s.gpuLabel)
                            AuroraNumber(value: gpu * 100, text: MetricFormat.percent(gpu), font: Aurora.Font.label)
                        }
                        .font(Aurora.Font.label)
                        .foregroundStyle(AuroraPalette(scheme).secondaryText)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .buttonStyle(AuroraTileButtonStyle(hue: .cpu))
        .accessibilityLabel(l10n.s.cpuLabel)
        .accessibilityValue(snapshot.cpuUsage.map { MetricFormat.percent($0) } ?? "–")
    }

    private var unit: TemperatureUnit { TemperatureUnit(rawValue: temperatureUnit) ?? .celsius }
}

// MARK: - Ring tiles

/// A wide tile with a gauge ring on the left and a label, value and caption.
struct RingTile: View {
    var title: String
    var value: String
    var numeric: Double
    var caption: String?
    var captionSymbol: String?
    var progress: Double
    var hue: Aurora.Hue
    var symbol: String
    var action: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                AuroraRing(progress: progress, hue: hue, lineWidth: 5) {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(hue.ink(scheme))
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(Aurora.Font.label)
                        .foregroundStyle(AuroraPalette(scheme).secondaryText)
                        .lineLimit(1)
                    AuroraNumber(value: numeric, text: value, font: Aurora.Font.metricSmall)
                    if let caption {
                        HStack(spacing: 3) {
                            if let captionSymbol {
                                Image(systemName: captionSymbol).font(.system(size: 8.5, weight: .bold))
                            }
                            Text(caption).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .font(Aurora.Font.caption)
                        .foregroundStyle(AuroraPalette(scheme).secondaryText)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity)
        }
        .buttonStyle(AuroraTileButtonStyle(hue: hue, padding: 10))
        .accessibilityElement(children: .combine)
    }
}

struct MemoryTile: View {
    var open: () -> Void
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var monitor = SystemMonitor.shared

    var body: some View {
        let s = monitor.snapshot
        let fraction: Double = {
            guard let used = s.memoryUsed, let total = s.memoryTotal, total > 0 else { return 0 }
            return Double(used) / Double(total)
        }()
        let caption: String? = {
            guard let used = s.memoryUsed, let total = s.memoryTotal else { return nil }
            return "\(MetricFormat.bytes(used)) / \(MetricFormat.bytes(total))"
        }()
        RingTile(title: l10n.s.memorySection,
                 value: s.memoryTotal == nil ? "–" : MetricFormat.percent(fraction),
                 numeric: fraction * 100,
                 caption: caption,
                 progress: fraction,
                 hue: pressureHue(s.memoryPressure),
                 symbol: "memorychip",
                 action: open)
    }

    private func pressureHue(_ pressure: MemoryPressure) -> Aurora.Hue {
        switch pressure {
        case .warning: return .power
        case .critical: return .sound
        default: return .memory
        }
    }
}

struct PowerTile: View {
    var open: () -> Void
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var monitor = SystemMonitor.shared

    var body: some View {
        let power = monitor.snapshot.power
        if let power, power.hasBattery, let charge = power.chargePercent {
            RingTile(title: l10n.s.batteryLabel,
                     value: "\(charge)%",
                     numeric: Double(charge),
                     caption: power.isCharging ? l10n.s.powerCharging : power.systemWatts.map(MetricFormat.wattsCompact),
                     captionSymbol: power.isCharging ? "bolt.fill" : nil,
                     progress: Double(charge) / 100,
                     hue: charge <= 15 && !power.isCharging ? .sound : .power,
                     symbol: power.isCharging ? "bolt.fill" : "battery.75percent",
                     action: open)
        } else {
            let watts = power?.systemWatts
            RingTile(title: l10n.s.powerSection,
                     value: watts.map(MetricFormat.wattsCompact) ?? "–",
                     numeric: watts ?? 0,
                     caption: power?.adapterMaxWatts.map(MetricFormat.wattsCompact),
                     captionSymbol: power?.adapterMaxWatts == nil ? nil : "powerplug.fill",
                     progress: min((watts ?? 0) / max(power?.adapterMaxWatts ?? 100, 1), 1),
                     hue: .power,
                     symbol: "bolt.fill",
                     action: open)
        }
    }
}

struct DiskTile: View {
    var open: () -> Void
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var monitor = SystemMonitor.shared

    var body: some View {
        let devices = monitor.snapshot.disk?.devices ?? []
        let main = devices.first(where: \.isInternal) ?? devices.first
        RingTile(title: l10n.s.diskSection,
                 value: main.map { MetricFormat.diskBytes($0.freeBytes) } ?? "–",
                 numeric: Double(main?.freeBytes ?? 0),
                 caption: main == nil ? nil : l10n.s.diskFree,
                 progress: main?.usedFraction ?? 0,
                 hue: (main?.usedFraction ?? 0) > 0.9 ? .sound : .disk,
                 symbol: "internaldrive",
                 action: open)
    }
}

// MARK: - Network

struct NetworkTile: View {
    var open: () -> Void
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var monitor = SystemMonitor.shared
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let s = monitor.snapshot
        Button(action: open) {
            ZStack(alignment: .bottom) {
                AuroraSparkline(values: s.netDownHistory, ceiling: nil, hue: .network,
                                lineWidth: 1.3, fillOpacity: 0.28, sampleCount: 30)
                    .frame(height: 34)
                    .padding(.horizontal, -10)
                    .padding(.bottom, -10)
                    .opacity(0.9)

                VStack(alignment: .leading, spacing: 3) {
                    Text(l10n.s.networkSection)
                        .font(Aurora.Font.label)
                        .foregroundStyle(AuroraPalette(scheme).secondaryText)
                    speed("arrow.down", s.netDownBytesPerSec)
                    speed("arrow.up", s.netUpBytesPerSec)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .buttonStyle(AuroraTileButtonStyle(hue: .network, padding: 10))
        .accessibilityElement(children: .combine)
    }

    private func speed(_ symbol: String, _ value: Double?) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(Aurora.Hue.network.ink(scheme))
            AuroraNumber(value: value ?? 0, text: value.map(MetricFormat.bytesPerSec) ?? "–",
                         font: Aurora.Font.headline)
        }
    }
}

// MARK: - Fan

struct FanTile: View {
    var open: () -> Void
    @ObservedObject private var monitor = SystemMonitor.shared
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let rpm = monitor.snapshot.fanSpeeds.max()
        Button(action: open) {
            HStack(spacing: 10) {
                // The blades turn at a pace that follows the real fan, scaled
                // down so 6000 rpm reads as busy rather than as a blur.
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || (rpm ?? 0) < 1)) { context in
                    let turnsPerSecond = min((rpm ?? 0) / 3000, 2.2)
                    let angle = context.date.timeIntervalSinceReferenceDate * turnsPerSecond * 360
                    AuroraHueBadge(systemImage: "fanblades.fill", hue: .fan, size: 40)
                        .overlay(
                            Image(systemName: "fanblades.fill")
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(.white)
                                .rotationEffect(.degrees(angle.truncatingRemainder(dividingBy: 360)))
                        )
                        .mask(RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 1) {
                    Text(FeatureStrings.fanControl(l10n.language).title)
                        .font(Aurora.Font.label)
                        .foregroundStyle(AuroraPalette(scheme).secondaryText)
                        .lineLimit(1)
                    AuroraNumber(value: rpm ?? 0, text: rpm.map { "\(Int($0.rounded())) rpm" } ?? "–",
                                 font: Aurora.Font.metricSmall)
                }
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity)
        }
        .buttonStyle(AuroraTileButtonStyle(hue: .fan, padding: 10))
    }
}

// MARK: - Volume

struct VolumeTile: View {
    var openMixer: () -> Void

    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @State private var dragValue: Double?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let device = mixer.outputDevices.first { $0.uid == mixer.currentOutputDeviceUID }
        AuroraTileContainer(hue: .sound, padding: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: device?.isHeadphones == true ? "headphones" : "hifispeaker.fill")
                        .font(.system(size: 9.5, weight: .semibold))
                    Text(device?.name ?? l10n.s.mixerSection)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    AuroraNumber(value: binding.wrappedValue * 100,
                                 text: "\(Int((binding.wrappedValue * 100).rounded()))%",
                                 font: Aurora.Font.micro)
                }
                .font(Aurora.Font.label)
                .foregroundStyle(AuroraPalette(scheme).secondaryText)

                HStack(spacing: 8) {
                    AuroraCapsuleSlider(value: binding,
                                        hue: .sound,
                                        symbol: Self.symbol,
                                        accessibilityLabel: device?.name ?? l10n.s.mixerSection,
                                        height: 30) { committed in
                        mixer.setCurrentOutputVolume(committed)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { dragValue = nil }
                    }
                    AuroraIconButton(systemImage: "slider.horizontal.3",
                                     help: l10n.s.mixerSection,
                                     size: 30,
                                     action: openMixer)
                }
            }
        }
    }

    private var binding: Binding<Double> {
        Binding {
            dragValue ?? (mixer.systemOutputMuted == true ? 0 : (mixer.systemOutputVolume ?? 0))
        } set: { value in
            dragValue = value
            mixer.setCurrentOutputVolume(value)
        }
    }

    static func symbol(_ level: Double) -> String {
        switch level {
        case ..<0.005: return "speaker.slash.fill"
        case ..<0.34: return "speaker.wave.1.fill"
        case ..<0.67: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }
}

// MARK: - Shortcut tile

/// A wide tile that leads into a section: hue badge, title, optional caption.
struct ShortcutTile: View {
    var title: String
    var caption: String?
    var symbol: String
    var hue: Aurora.Hue
    var action: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                AuroraHueBadge(systemImage: symbol, hue: hue, size: 32)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(Aurora.Font.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    if let caption {
                        Text(caption)
                            .font(Aurora.Font.caption)
                            .foregroundStyle(AuroraPalette(scheme).secondaryText)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(AuroraPalette(scheme).tertiaryText)
            }
            .frame(maxHeight: .infinity)
        }
        .buttonStyle(AuroraTileButtonStyle(hue: hue, padding: 10))
    }
}

// MARK: - Quick tools

/// A one-cell tile that runs a tool straight away.
struct QuickToolTile: View {
    var title: String
    var symbol: String
    var hue: Aurora.Hue = .tools
    var active = false
    var action: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(active ? AnyShapeStyle(Color.white) : AnyShapeStyle(hue.gradient))
                    .symbolEffect(.bounce, value: taps)
                    .frame(height: 24)
                Text(title)
                    .font(.system(size: 9.5, weight: .medium, design: .rounded))
                    .foregroundStyle(active ? Color.white.opacity(0.9) : AuroraPalette(scheme).secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(AuroraTileButtonStyle(hue: active ? .sound : nil, filled: active, padding: 6))
        .help(title)
        .accessibilityLabel(title)
    }
}

/// The tools a one-cell tile can run without first showing a panel of its own.
/// Tools that do need the panel (downloads, clipboard, cleaners) stay one
/// step away, behind "All tools".
extension UtilityPanelItem {
    var isQuickAction: Bool {
        switch self {
        case .screenshot, .screenRecorder, .colorPicker, .screenOCR, .quickLauncher, .scratchpad,
             .cameraPreview, .commandBar:
            return true
        default:
            return false
        }
    }

    var needsScreenRecording: Bool {
        switch self {
        case .screenshot, .screenRecorder, .screenOCR: return true
        default: return false
        }
    }

    var visibilityKey: String? {
        switch self {
        case .screenshot: return DefaultsKey.panelUtilityScreenshot
        case .screenRecorder: return DefaultsKey.panelUtilityScreenRecorder
        case .colorPicker: return DefaultsKey.panelUtilityColorPicker
        case .screenOCR: return DefaultsKey.panelUtilityScreenOCR
        case .quickLauncher: return DefaultsKey.panelUtilityQuickLauncher
        case .scratchpad: return DefaultsKey.panelUtilityScratchpad
        case .cameraPreview: return DefaultsKey.panelUtilityCameraPreview
        case .commandBar: return DefaultsKey.panelUtilityCommandBar
        default: return nil
        }
    }

    var isShownInPanel: Bool {
        guard feature.isAvailable, let key = visibilityKey else { return false }
        return UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    func quickSymbol(recording: Bool) -> String {
        switch self {
        case .screenshot: return "camera.viewfinder"
        case .screenRecorder: return recording ? "stop.circle.fill" : "record.circle"
        case .colorPicker: return "eyedropper"
        case .screenOCR: return "text.viewfinder"
        case .quickLauncher: return "square.grid.2x2"
        case .scratchpad: return "note.text"
        case .cameraPreview: return "web.camera"
        case .commandBar: return "command"
        default: return "wrench.and.screwdriver"
        }
    }

    func quickTitle(_ l10n: L10n, recording: Bool) -> String {
        switch self {
        case .screenshot: return FeatureStrings.screenshot(l10n.language).pageTitle
        case .screenRecorder:
            let strings = FeatureStrings.recorder(l10n.language)
            return recording ? strings.stopButton : strings.pageTitle
        case .colorPicker: return l10n.s.colorPickerName
        case .screenOCR: return l10n.s.ocrName
        case .quickLauncher: return l10n.s.launcherName
        case .scratchpad: return FeatureStrings.scratchpad(l10n.language).pageTitle
        case .cameraPreview: return FeatureStrings.cameraPreview(l10n.language).pageTitle
        case .commandBar: return FeatureStrings.commandBar(l10n.language).pageTitle
        default: return ""
        }
    }

    /// Closes the panel first, as the list did, so the tool's own window or
    /// capture overlay is the only thing on screen.
    func runQuickAction() {
        appDelegate()?.closePopover()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            switch self {
            case .screenshot: ScreenshotService.shared.capture()
            case .screenRecorder: ScreenRecorderService.shared.toggle()
            case .colorPicker: ColorSamplerService.shared.pick()
            case .screenOCR: ScreenTextService.shared.capture()
            case .quickLauncher: QuickLauncherService.shared.show()
            case .scratchpad: ScratchpadService.shared.show()
            case .cameraPreview: CameraPreviewService.shared.show()
            case .commandBar: CommandBarService.shared.show()
            default: break
            }
        }
    }
}
