// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

// MARK: - Routing

/// Where the panel is: the bento home, one section, or one metric's detail.
enum PanelRoute: Equatable {
    case home
    case section(PanelSectionID)
    case metric(MetricDetailKind)

    var hue: Aurora.Hue {
        switch self {
        case .home: return .neutral
        case .section(let id): return .forSection(id)
        case .metric(let kind): return .forMetric(kind)
        }
    }

    var key: String {
        switch self {
        case .home: return "home"
        case .section(let id): return "section." + id.rawValue
        case .metric(let kind): return "metric." + kind.rawValue
        }
    }
}

/// Owns the panel's route so AppKit can step back from a detail page on
/// Escape instead of closing the whole panel.
final class PanelRouter: ObservableObject {
    static let shared = PanelRouter()

    @Published private(set) var route: PanelRoute = .home
    /// Where the detail page grows from: the centre of the tile that opened it.
    @Published private(set) var zoomAnchor: UnitPoint = .center
    /// The page being left, while its transition runs. The popover window
    /// takes its new size at once rather than following SwiftUI's animation,
    /// so the panel keeps the larger of the two sizes until the old page has
    /// gone, then settles; nothing is cut off mid-transition.
    @Published private(set) var departingRoute: PanelRoute?
    /// How much of the departing page's height the panel still keeps: 1 while
    /// the transition runs, then easing to 0 as the panel settles. It is
    /// stepped by hand, frame by frame, because the popover window follows
    /// each step but not a SwiftUI animation.
    @Published private(set) var departureBlend: CGFloat = 0
    private var departureSerial = 0
    private var settleTimer: Timer?

    private init() {}

    private func holdSize(of old: PanelRoute) {
        settleTimer?.invalidate()
        departingRoute = old
        departureBlend = 1
        departureSerial += 1
        let serial = departureSerial
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.2 : 0.42)) { [weak self] in
            guard let self, self.departureSerial == serial else { return }
            self.settle(serial: serial, duration: reduceMotion ? 0 : 0.26)
        }
    }

    private func settle(serial: Int, duration: TimeInterval) {
        let start = CACurrentMediaTime()
        let finish = { [weak self] in
            guard let self else { return }
            self.settleTimer?.invalidate()
            self.settleTimer = nil
            self.withoutAnimation {
                self.departureBlend = 0
                self.departingRoute = nil
            }
        }
        guard duration > 0 else { return finish() }
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self, self.departureSerial == serial else { return }
            let progress = min((CACurrentMediaTime() - start) / duration, 1)
            if progress >= 1 { return finish() }
            let eased = 1 - pow(1 - progress, 3)
            self.withoutAnimation { self.departureBlend = CGFloat(1 - eased) }
        }
        settleTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func withoutAnimation(_ body: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, body)
    }

    private var animation: Animation {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? Aurora.Motion.reduced
            : .spring(response: 0.48, dampingFraction: 0.86)
    }

    func open(_ next: PanelRoute, from anchor: UnitPoint = .center) {
        guard next != route else { return }
        zoomAnchor = anchor
        holdSize(of: route)
        withAnimation(animation) { route = next }
    }

    /// Back to the home grid. Returns false when already there, so the caller
    /// can fall through to closing the panel.
    @discardableResult
    func goHome() -> Bool {
        guard route != .home else { return false }
        // A hosted tool (a download in progress, the cleaner) owns the page;
        // Escape must not tear it down underneath the person.
        guard !PanelInteractionState.shared.preventsPopoverDismissal else { return false }
        holdSize(of: route)
        withAnimation(animation) { route = .home }
        return true
    }

    /// Sets the route without a transition, for focus requests that arrive
    /// while the panel is opening.
    func jump(to next: PanelRoute) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { route = next }
    }
}

// MARK: - Home tiles

private enum HomeTile: Identifiable, Equatable {
    case keepAwake, cpu, memory, power, network, disk, fan, brightness, volume, mixer
    case tool(UtilityPanelItem)
    case allTools, controls, toggles

    var id: String {
        switch self {
        case .tool(let item): return "tool." + item.rawValue
        default: return String(describing: self)
        }
    }

    var span: BentoSpan {
        switch self {
        case .keepAwake, .cpu: return .large
        case .volume: return .banner
        case .tool, .allTools: return .small
        default: return .wide
        }
    }

    var destination: PanelRoute {
        switch self {
        case .keepAwake: return .section(.keepAwake)
        case .cpu: return .section(.system)
        case .memory: return .metric(.memory)
        case .power: return .section(.power)
        case .network: return .section(.network)
        case .disk: return .section(.disk)
        case .fan: return .section(.fanControl)
        case .brightness: return .section(.brightness)
        case .volume, .mixer: return .section(.mixer)
        case .tool, .allTools: return .section(.utilities)
        case .controls: return .section(.controls)
        case .toggles: return .section(.toggles)
        }
    }
}

private struct TileFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

private struct RouteHeightKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue()) { $1 }
    }
}

private struct BannerHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

// MARK: - Panel

/// The menu bar panel. Opens on a bento grid of live tiles; a tile grows into
/// its section's page, and Back (or Escape) shrinks it home again.
struct MenuPanelView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var updates = UpdateService.shared
    @ObservedObject private var panelFocus = MenuPanelFocus.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @ObservedObject private var router = PanelRouter.shared
    @ObservedObject private var awake = KeepAwakeManager.shared
    @ObservedObject private var mixer = AppVolumeMixer.shared
    @ObservedObject private var recorder = ScreenRecorderService.shared
    @ObservedObject private var permissions = Permissions.shared
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(DefaultsKey.monitorShowMixer) private var showMixer = true
    @AppStorage(DefaultsKey.monitorShowSystem) private var showSystem = true
    @AppStorage(DefaultsKey.monitorShowNetwork) private var showNetwork = true
    @AppStorage(DefaultsKey.monitorShowDisk) private var showDisk = true
    @AppStorage(DefaultsKey.monitorShowPower) private var showPower = true
    @AppStorage(DefaultsKey.panelShowFanControl) private var showFanControl = true
    @AppStorage(DefaultsKey.panelShowKeepAwake) private var showKeepAwake = true
    @AppStorage(DefaultsKey.panelShowBrightness) private var showBrightness = true
    @AppStorage(DefaultsKey.brightnessControlEnabled) private var brightnessEnabled = false
    @AppStorage(DefaultsKey.panelShowUtilities) private var showUtilities = true
    @AppStorage(DefaultsKey.panelShowControls) private var showControls = true
    @AppStorage(DefaultsKey.panelShowToggles) private var showToggles = true
    @AppStorage(DefaultsKey.panelSectionOrder) private var sectionOrderRaw = ""
    @AppStorage(DefaultsKey.panelUtilityOrder) private var utilityOrderRaw = ""

    @State private var routeHeights: [String: CGFloat] = [:]
    @State private var tileFrames: [String: CGRect] = [:]
    @State private var bannerHeight: CGFloat = 0
    @State private var entered = false

    private let headerHeight: CGFloat = 32
    private let stackSpacing: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: stackSpacing) {
            UpdateBanner()
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: BannerHeightKey.self, value: proxy.size.height)
                })

            header
                .frame(height: headerHeight)

            ZStack(alignment: .top) {
                if route == .home {
                    scroller(for: .home) { home }
                        .transition(homeTransition)
                } else {
                    scroller(for: route) { detail(route) }
                        .id(route.key)
                        .transition(detailTransition)
                }
            }
            // The scroll area bleeds into the panel's padding so tile glows
            // and card shadows are not cut off at a hard rectangle; the
            // content inside is inset by the same amount.
            .frame(width: Aurora.Panel.width, height: scrollHeight + Self.bleed * 2, alignment: .top)
            .padding(.horizontal, -Aurora.Panel.padding)
            .padding(.vertical, -Self.bleed)
        }
        .padding(Aurora.Panel.padding)
        .frame(width: Aurora.Panel.width, height: panelHeight, alignment: .top)
        // The popover draws its own frame a few points outside the content;
        // the backdrop reaches under it so the glass meets the popover's edge
        // instead of leaving a dark band between two borders.
        .background(AuroraBackdrop(hue: route.hue, accent: route == .home && awake.isActive ? .sunrise : nil)
                        .padding(-8))
        .scaleEffect(entered || reduceMotion ? 1 : 0.975, anchor: .top)
        .coordinateSpace(name: Self.space)
        .onPreferenceChange(TileFrameKey.self) { tileFrames = $0 }
        .onPreferenceChange(RouteHeightKey.self) { heights in
            let changed = heights.contains { key, value in abs((routeHeights[key] ?? 0) - value) > 0.5 }
            guard changed else { return }
            // Not animated: the popover window snaps to its new size, and a
            // SwiftUI height animation would only drift out of step with it.
            DispatchQueue.main.async {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { routeHeights.merge(heights) { $1 } }
            }
        }
        .onPreferenceChange(BannerHeightKey.self) { value in
            guard abs(value - bannerHeight) > 0.5 else { return }
            DispatchQueue.main.async { bannerHeight = value }
        }
        .onAppear {
            applyFocus(panelFocus.request)
            KeepAwakeManager.shared.refreshPasswordlessStatus()
            syncMonitorSampling()
            playEntrance()
        }
        .onReceive(NotificationCenter.default.publisher(for: .menuPanelWillShow)) { _ in
            syncMonitorSampling()
            playEntrance()
        }
        .onDisappear {
            if !panelFocus.isSwitchingMetricAnchor {
                SystemMonitor.shared.setMenuPanelNeeds(.none)
            }
        }
        .onChange(of: monitorNeeds) { _, _ in syncMonitorSampling() }
        .onChange(of: panelFocus.request) { _, request in applyFocus(request) }
        .onChange(of: route) { _, newRoute in
            if newRoute == .home { MenuPanelFocus.shared.clearMetricFocus() }
            if case .section(let id) = newRoute, id != .utilities {
                PanelInteractionState.shared.hostedSettingsPage = nil
            }
        }
    }

    static let space = "auroraPanel"
    /// How far the scroll area reaches above and below its slot.
    static let bleed: CGFloat = 8

    private var route: PanelRoute { router.route }

    // MARK: Header

    @ViewBuilder
    private var header: some View {
        ZStack {
            if route == .home {
                homeHeader.transition(.opacity.combined(with: .offset(x: -16)))
            } else {
                detailHeader.transition(.opacity.combined(with: .offset(x: 16)))
            }
        }
    }

    private var homeHeader: some View {
        HStack(spacing: 9) {
            BrandBadge(size: 26)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Text(AppInfo.name)
                    .font(Aurora.Font.headline)
                TimelineView(.periodic(from: .now, by: 60)) { _ in
                    Text("\(l10n.s.systemUptime) \(Self.uptime())")
                        .font(Aurora.Font.caption)
                        .foregroundStyle(AuroraPalette(scheme).secondaryText)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            AuroraIconButton(systemImage: "gearshape.fill", help: l10n.s.panelSettings, action: openSettings)
            AuroraIconButton(systemImage: "power", help: l10n.s.panelQuit) { NSApp.terminate(nil) }
        }
    }

    private var detailHeader: some View {
        HStack(spacing: 8) {
            AuroraIconButton(systemImage: "chevron.left", help: l10n.s.obBack) {
                router.goHome()
            }
            .keyboardShortcut("[", modifiers: .command)

            AuroraHueBadge(systemImage: routeSymbol, hue: route.hue, size: 24)
                .id(route.key)
                .transition(.scale.combined(with: .opacity))

            Text(routeTitle)
                .font(Aurora.Font.title)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)

            AuroraIconButton(systemImage: "gearshape.fill", help: l10n.s.panelSettings, action: openSettings)
        }
    }

    private var routeTitle: String {
        switch route {
        case .home: return AppInfo.name
        case .section(let id): return id.title(l10n.s)
        case .metric(let kind): return kind.title(l10n.s)
        }
    }

    private var routeSymbol: String {
        switch route {
        case .home: return "square.grid.2x2.fill"
        case .section(let id): return id.symbolName
        case .metric(let kind): return kind.symbolName
        }
    }

    private func openSettings() {
        // The hosted utility's own page, or the general one from the
        // panel's lists: the router is sticky, so it is set every time.
        SettingsRouter.shared.page = PanelInteractionState.shared.hostedSettingsPage ?? .general
        appDelegate()?.openSettingsWindow()
    }

    // MARK: Home

    private var home: some View {
        BentoLayout {
            ForEach(Array(homeTiles.enumerated()), id: \.element.id) { index, tile in
                tileView(tile)
                    .bentoSpan(tile.span)
                    .auroraEntrance(index, visible: entered)
                    .background(GeometryReader { proxy in
                        Color.clear.preference(key: TileFrameKey.self,
                                               value: [tile.id: proxy.frame(in: .named(Self.space))])
                    })
            }
        }
        .frame(width: Aurora.Panel.contentWidth)
        .animation(reduceMotion ? nil : Aurora.Motion.smooth, value: homeTiles)
    }

    private var homeTiles: [HomeTile] {
        _ = sectionOrderRaw
        _ = utilityOrderRaw
        var tiles: [HomeTile] = []
        for id in visibleSections {
            switch id {
            case .keepAwake: tiles.append(.keepAwake)
            case .system:
                if AppFeature.monitorCPU.isAvailable || AppFeature.monitorGPU.isAvailable { tiles.append(.cpu) }
                if AppFeature.monitorMemory.isAvailable { tiles.append(.memory) }
            case .power: tiles.append(.power)
            case .network: tiles.append(.network)
            case .disk: tiles.append(.disk)
            case .fanControl: tiles.append(.fan)
            case .brightness: tiles.append(.brightness)
            case .mixer:
                tiles.append(AppVolumeMixer.isSupported && mixer.systemOutputVolume != nil ? .volume : .mixer)
            case .utilities:
                let quick = PanelLayout.itemOrder(UtilityPanelItem.self, key: DefaultsKey.panelUtilityOrder)
                    .filter { $0.isQuickAction && $0.isShownInPanel }
                    .prefix(3)
                tiles.append(contentsOf: quick.map(HomeTile.tool))
                tiles.append(.allTools)
            case .controls: tiles.append(.controls)
            case .toggles: tiles.append(.toggles)
            }
        }
        return tiles
    }

    @ViewBuilder
    private func tileView(_ tile: HomeTile) -> some View {
        let open = { open(tile) }
        switch tile {
        case .keepAwake: KeepAwakeTile(openDetail: open)
        case .cpu: CPUTile(open: open)
        case .memory: MemoryTile(open: open)
        case .power: PowerTile(open: open)
        case .network: NetworkTile(open: open)
        case .disk: DiskTile(open: open)
        case .fan: FanTile(open: open)
        case .volume: VolumeTile(openMixer: open)
        case .mixer:
            ShortcutTile(title: l10n.s.mixerSection, caption: nil, symbol: "slider.horizontal.3",
                         hue: .sound, action: open)
        case .brightness:
            ShortcutTile(title: PanelSectionID.brightness.title(l10n.s), caption: nil, symbol: "sun.max.fill",
                         hue: .brightness, action: open)
        case .controls:
            ShortcutTile(title: PanelSectionID.controls.title(l10n.s), caption: nil, symbol: "switch.2",
                         hue: .controls, action: open)
        case .toggles:
            ShortcutTile(title: PanelSectionID.toggles.title(l10n.s), caption: nil, symbol: "togglepower",
                         hue: .toggles, action: open)
        case .allTools:
            QuickToolTile(title: AuroraStrings.allTools(l10n.language), symbol: "square.grid.3x3.fill",
                          hue: .tools, action: open)
        case .tool(let item):
            let recording = recorder.isRecording
            QuickToolTile(title: item.quickTitle(l10n, recording: recording),
                          symbol: item.quickSymbol(recording: recording),
                          active: item == .screenRecorder && recording) {
                if item.needsScreenRecording && !permissions.screenRecording {
                    open()
                } else {
                    item.runQuickAction()
                }
            }
        }
    }

    private func open(_ tile: HomeTile) {
        router.open(tile.destination, from: anchor(for: tile))
    }

    private func anchor(for tile: HomeTile) -> UnitPoint {
        guard let frame = tileFrames[tile.id] else { return .center }
        // Relative to the content area, which is what the detail page fills.
        let top = Aurora.Panel.padding + headerHeight + stackSpacing + bannerOffset
        let x = (frame.midX - Aurora.Panel.padding) / Aurora.Panel.contentWidth
        let y = (frame.midY - top) / max(scrollHeight, 1)
        return UnitPoint(x: min(max(x, 0), 1), y: min(max(y, 0), 1))
    }

    // MARK: Detail

    @ViewBuilder
    private func detail(_ route: PanelRoute) -> some View {
        Group {
            switch route {
            case .home:
                EmptyView()
            case .section(let id):
                section(for: id)
                    .environment(\.panelSectionTitleHidden, true)
            case .metric(let kind):
                MetricDetailView(kind: kind)
            }
        }
        .frame(width: Aurora.Panel.contentWidth)
        .environment(\.auroraHue, route.hue)
        .tint(route.hue.controlTint(scheme))
    }

    @ViewBuilder
    private func section(for id: PanelSectionID) -> some View {
        switch id {
        case .keepAwake: KeepAwakeCard(collapsible: false)
        case .brightness: BrightnessSection(collapsible: false)
        case .mixer: MixerSection(collapsible: false)
        case .system: SystemSection(collapsible: false)
        case .network: NetworkSection(collapsible: false)
        case .disk: DiskSection(collapsible: false)
        case .power: PowerSection(collapsible: false)
        case .fanControl: FanControlSection(collapsible: false)
        case .utilities: UtilitiesSection(collapsible: false, startCleaning: startCleaning)
        case .controls: QuickControlsSection(collapsible: false)
        case .toggles: QuickTogglesSection(collapsible: false)
        }
    }

    /// Starts cleaning mode and closes the panel so the lock overlay is the only
    /// thing on screen.
    private func startCleaning() {
        appDelegate()?.closePopover()
        CleaningModeManager.shared.activate()
    }

    // MARK: Scrolling and size

    /// A scroll view that reports its content's natural height, so the panel
    /// can size itself to fit and only scroll once it would pass the screen.
    private func scroller<Content: View>(for route: PanelRoute,
                                         @ViewBuilder content: () -> Content) -> some View {
        let key = route.key
        let overflows = (routeHeights[key] ?? 0) > scrollHeight(for: route) + 1
        return ScrollView(.vertical) {
            content()
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: RouteHeightKey.self, value: [key: proxy.size.height])
                })
                .padding(.horizontal, Aurora.Panel.padding)
                .padding(.vertical, Self.bleed)
        }
        // A legacy scroller would reserve a gutter and push the fixed-width
        // column off centre; the panel scrolls by trackpad or wheel and
        // fades its edges instead when there is more to see.
        .scrollIndicators(.never)
        .scrollBounceBehavior(.basedOnSize)
        .mask {
            LinearGradient(stops: [
                .init(color: overflows ? .clear : .black, location: 0),
                .init(color: .black, location: overflows ? 0.035 : 0),
                .init(color: .black, location: overflows ? 0.94 : 1),
                .init(color: overflows ? .clear : .black, location: 1),
            ], startPoint: .top, endPoint: .bottom)
        }
    }

    /// Cap the panel to the usable screen height so it never overflows the menu
    /// bar; taller content scrolls inside. Measured against the display the
    /// menu bar icon is on, which is not always the one holding the key window.
    private var maxHeight: CGFloat {
        let anchored = PanelInteractionState.shared.anchorScreen
            .flatMap { anchor in anchor.isStillAttached ? anchor : nil }
        return max(360, ((anchored ?? NSScreen.withMenuBar)?.visibleFrame.height ?? 760) - 24)
    }

    private var bannerOffset: CGFloat {
        updates.state.showsMenuPanelBanner ? max(bannerHeight, 44) + stackSpacing : 0
    }

    private var chromeHeight: CGFloat {
        Aurora.Panel.padding * 2 + headerHeight + stackSpacing + bannerOffset
    }

    private var scrollHeight: CGFloat {
        let target = scrollHeight(for: route)
        guard let departing = router.departingRoute else { return target }
        let held = scrollHeight(for: departing)
        guard held > target else { return target }
        return (target + (held - target) * router.departureBlend).rounded()
    }

    private func scrollHeight(for route: PanelRoute) -> CGFloat {
        let measured = routeHeights[route.key] ?? estimatedHeight(for: route)
        return min(max(measured, 60), max(80, maxHeight - chromeHeight))
    }

    private var panelHeight: CGFloat {
        min(maxHeight, scrollHeight + chromeHeight)
    }

    private func estimatedHeight(for route: PanelRoute) -> CGFloat {
        switch route {
        case .home: return 400
        case .section(let id):
            switch id {
            case .keepAwake: return 250
            case .brightness: return 140
            case .mixer: return 250
            case .system: return 460
            case .network: return 190
            case .disk: return 360
            case .power: return 170
            case .fanControl: return 220
            case .utilities: return 500
            case .controls: return 360
            case .toggles: return 420
            }
        case .metric(let kind):
            switch kind {
            case .cpu, .gpu, .memory: return 430
            case .network: return 330
            case .disk: return 360
            case .battery, .power: return 360
            case .fan: return 240
            }
        }
    }

    // MARK: Transitions

    private var homeTransition: AnyTransition {
        reduceMotion ? .opacity : .auroraZoom(scale: 1.07, blur: 6, anchor: router.zoomAnchor)
    }

    private var detailTransition: AnyTransition {
        reduceMotion ? .opacity : .auroraZoom(scale: 0.6, blur: 8, anchor: router.zoomAnchor)
    }

    private func playEntrance() {
        guard !reduceMotion else {
            entered = true
            return
        }
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { entered = false }
        DispatchQueue.main.async {
            withAnimation(Aurora.Motion.bouncy) { entered = true }
        }
    }

    // MARK: Sections and focus

    private var orderedSections: [PanelSectionID] {
        _ = sectionOrderRaw
        return PanelLayout.order
    }

    private var visibleSections: [PanelSectionID] {
        orderedSections.filter(isSectionVisible)
    }

    private func isSectionVisible(_ id: PanelSectionID) -> Bool {
        guard id.isAvailable else { return false }
        switch id {
        case .keepAwake: return showKeepAwake
        // Brightness only earns a tile while the feature is on; it is
        // switched on in Settings, not from an empty panel screen.
        case .brightness: return showBrightness && brightnessEnabled
        case .mixer: return showMixer
        case .system: return showSystem
        case .network: return showNetwork
        case .disk: return showDisk
        case .power: return showPower
        case .fanControl: return showFanControl
        case .utilities: return showUtilities
        case .controls: return showControls
        case .toggles: return showToggles
        }
    }

    private func applyFocus(_ request: MenuPanelFocusRequest?) {
        guard let request else { return }
        switch request.target {
        case .normal:
            // A hosted tool mid-task keeps its page; everything else reopens
            // on the home grid, the way Control Center does.
            if !PanelInteractionState.shared.preventsPopoverDismissal {
                router.jump(to: .home)
            }
        case .section(let section):
            guard isSectionVisible(section) else { return }
            router.jump(to: .section(section))
        case .metric(let metric):
            router.jump(to: .metric(metric))
        }
    }

    private var monitorNeeds: SystemMonitorPanelNeeds {
        switch route {
        case .home:
            let visible = Set(visibleSections)
            return SystemMonitorPanelNeeds(system: visible.contains(.system),
                                           network: visible.contains(.network),
                                           disk: visible.contains(.disk),
                                           power: visible.contains(.power),
                                           fanSpeed: visible.contains(.fanControl))
        case .metric(let kind):
            return kind.monitorNeeds
        case .section(let id):
            switch id {
            case .system: return SystemMonitorPanelNeeds(system: true)
            case .network: return SystemMonitorPanelNeeds(network: true)
            case .disk: return SystemMonitorPanelNeeds(disk: true)
            case .power: return SystemMonitorPanelNeeds(power: true)
            case .fanControl: return SystemMonitorPanelNeeds(fanSpeed: true)
            default: return .none
            }
        }
    }

    private func syncMonitorSampling() {
        SystemMonitor.shared.setMenuPanelNeeds(monitorNeeds)
    }

    private static func uptime() -> String {
        let total = SystemInfo.wallClockUptimeSeconds() ?? Int(ProcessInfo.processInfo.systemUptime)
        return MetricFormat.uptime(total)
    }
}

// MARK: - Zoom transition

private struct AuroraZoomModifier: ViewModifier {
    let scale: CGFloat
    let blur: CGFloat
    let opacity: Double
    let anchor: UnitPoint

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale, anchor: anchor)
            .blur(radius: blur)
            .opacity(opacity)
    }
}

extension AnyTransition {
    /// Scale, blur and fade around an anchor: the detail page grows out of the
    /// tile that opened it, and the grid behind it falls slightly forward.
    static func auroraZoom(scale: CGFloat, blur: CGFloat, anchor: UnitPoint) -> AnyTransition {
        .modifier(active: AuroraZoomModifier(scale: scale, blur: blur, opacity: 0, anchor: anchor),
                  identity: AuroraZoomModifier(scale: 1, blur: 0, opacity: 1, anchor: anchor))
    }
}
