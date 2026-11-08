//
//  SettingsView.swift
//  Notchly
//
//  Created by Richard Kunkli on 07/08/2024.
//

import AVFoundation
import Defaults
import EventKit
import KeyboardShortcuts
import LaunchAtLogin
import Sparkle
import SwiftUI
import SwiftUIIntrospect

struct SettingsView: View {
    @State private var selectedTab = "General"
    @State private var accentColorUpdateTrigger = UUID()

    let updaterController: SPUStandardUpdaterController?

    init(updaterController: SPUStandardUpdaterController? = nil) {
        self.updaterController = updaterController
    }

    /// A sidebar row with a System Settings style coloured icon tile.
    private func item(_ tag: String, _ symbol: String, _ color: Color, title: String? = nil, badge: Bool = false) -> some View {
        NavigationLink(value: tag) {
            HStack {
                Label {
                    Text(title ?? tag)
                } icon: {
                    // Every symbol is fitted into the same 14pt box so the tiles look alike
                    Image(systemName: symbol)
                        .resizable()
                        .scaledToFit()
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .frame(width: 14, height: 14)
                        .frame(width: 24, height: 24)
                        .background(color.gradient, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                if badge { customBadge(text: "Beta") }
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Section("Notch") {
                    item("General", "laptopcomputer", .gray)
                    item("HUD", "speaker.wave.2.fill", .teal, title: "HUDs")
                    item("Tabs", "rectangle.split.2x1.fill", .indigo, title: "Tabs & Home")
                }
                Section("Features") {
                    item("Agents", "terminal.fill", .purple, title: "AI Integrations", badge: true)
                    item("Calendar", "calendar", .red)
                    item("Media", "music.note", .pink, title: "Music")
                    item("Shelf", "tray.and.arrow.down.fill", .orange)
                    item("Teleprompter", "text.alignleft", .mint)
                    item("Tools", "wrench.and.screwdriver.fill", .brown, title: "Tools")
                }
                Section("App") {
                    item("About", "info.circle.fill", .blue)
                    item("Advanced", "slider.horizontal.3", .gray)
                    item("Shortcuts", "command", .gray)
                }
            }
            .listStyle(SidebarListStyle())
            .tint(.effectiveAccent)
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(215)
        } detail: {
            Group {
                switch selectedTab {
                case "General":
                    GeneralSettings()
                case "Tabs":
                    TabsSettings()
                case "Media":
                    Media()
                case "Calendar":
                    CalendarSettings()
                case "HUD":
                    HUD()
                case "Shelf":
                    Shelf()
                case "Tools":
                    ToolsSettings()
                case "Teleprompter":
                    TeleprompterSettings()
                case "Agents":
                    AgentsSettings()
                case "Shortcuts":
                    Shortcuts()
                case "Extensions":
                    GeneralSettings()
                case "Advanced":
                    Advanced()
                case "About":
                    if let controller = updaterController {
                        About(updaterController: controller)
                    } else {
                        // Fallback with a default controller
                        About(
                            updaterController: SPUStandardUpdaterController(
                                startingUpdater: false, updaterDelegate: nil,
                                userDriverDelegate: nil))
                    }
                default:
                    GeneralSettings()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("")
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 700)
        .background(Color(NSColor.windowBackgroundColor))
        .tint(.effectiveAccent)
        .id(accentColorUpdateTrigger)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AccentColorChanged"))) { _ in
            accentColorUpdateTrigger = UUID()
        }
    }
}

struct GeneralSettings: View {
    @State private var screens: [(uuid: String, name: String)] = NSScreen.screens.compactMap { screen in
        guard let uuid = screen.displayUUID else { return nil }
        return (uuid, screen.localizedName)
    }
    @EnvironmentObject var vm: NotchlyViewModel
    @ObservedObject var coordinator = NotchlyViewCoordinator.shared

    @Default(.showEmojis) var showEmojis
    @Default(.minimumHoverDuration) var minimumHoverDuration
    @Default(.nonNotchHeight) var nonNotchHeight
    @Default(.nonNotchHeightMode) var nonNotchHeightMode
    @Default(.notchHeight) var notchHeight
    @Default(.notchHeightMode) var notchHeightMode
    @Default(.nonNotchWidth) var nonNotchWidth
    @Default(.islandTopGap) var islandTopGap
    @Default(.notchShapeStyle) var notchShapeStyle
    @Default(.notchBackgroundStyle) var notchBackgroundStyle
    @Default(.showOnAllDisplays) var showOnAllDisplays
    @Default(.automaticallySwitchDisplay) var automaticallySwitchDisplay
    @Default(.openNotchOnHover) var openNotchOnHover
    

    var body: some View {
        Form {
            Section {
                LaunchAtLogin.Toggle("Launch at login")
                Defaults.Toggle(key: .showOnAllDisplays) {
                    Text("Show on all displays")
                }
                .onChange(of: showOnAllDisplays) {
                    NotificationCenter.default.post(
                        name: Notification.Name.showOnAllDisplaysChanged, object: nil)
                }
                Picker("Preferred display", selection: $coordinator.preferredScreenUUID) {
                    ForEach(screens, id: \.uuid) { screen in
                        Text(screen.name).tag(screen.uuid as String?)
                    }
                }
                .onChange(of: NSScreen.screens) {
                    screens = NSScreen.screens.compactMap { screen in
                        guard let uuid = screen.displayUUID else { return nil }
                        return (uuid, screen.localizedName)
                    }
                }
                .disabled(showOnAllDisplays)
                
                Defaults.Toggle(key: .automaticallySwitchDisplay) {
                    Text("Automatically switch displays")
                }
                    .onChange(of: automaticallySwitchDisplay) {
                        NotificationCenter.default.post(
                            name: Notification.Name.automaticallySwitchDisplayChanged, object: nil)
                    }
                    .disabled(showOnAllDisplays)
            } header: {
                Text("System features")
            }

            Section {
                Picker("Shape", selection: $notchShapeStyle) {
                    ForEach(NotchShapeStyle.allCases) { Text($0.rawValue).tag($0) }
                }
                .onChange(of: notchShapeStyle) {
                    NotificationCenter.default.post(name: Notification.Name.notchHeightChanged, object: nil)
                }
                Picker("Open notch background", selection: $notchBackgroundStyle) {
                    ForEach(NotchBackgroundStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
            } header: {
                Text("Notch style")
            }

            Section {
                Picker(
                    selection: $notchHeightMode,
                    label:
                        Text("Notch height on notch displays")
                ) {
                    Text("Match real notch height")
                        .tag(WindowHeightMode.matchRealNotchSize)
                    Text("Match menu bar height")
                        .tag(WindowHeightMode.matchMenuBar)
                    Text("Custom height")
                        .tag(WindowHeightMode.custom)
                }
                .onChange(of: notchHeightMode) {
                    switch notchHeightMode {
                    case .matchRealNotchSize:
                        notchHeight = 38
                    case .matchMenuBar:
                        notchHeight = 44
                    case .custom:
                        notchHeight = 38
                    }
                    NotificationCenter.default.post(
                        name: Notification.Name.notchHeightChanged, object: nil)
                }
                if notchHeightMode == .custom {
                    Slider(value: $notchHeight, in: 15...45, step: 1) {
                        Text("Custom notch size - \(notchHeight, specifier: "%.0f")")
                    }
                    .onChange(of: notchHeight) {
                        NotificationCenter.default.post(
                            name: Notification.Name.notchHeightChanged, object: nil)
                    }
                }
                Picker("Notch height on non-notch displays", selection: $nonNotchHeightMode) {
                    Text("Match menubar height")
                        .tag(WindowHeightMode.matchMenuBar)
                    Text("Match real notch height")
                        .tag(WindowHeightMode.matchRealNotchSize)
                    Text("Custom height")
                        .tag(WindowHeightMode.custom)
                }
                .onChange(of: nonNotchHeightMode) {
                    switch nonNotchHeightMode {
                    case .matchMenuBar:
                        nonNotchHeight = 24
                    case .matchRealNotchSize:
                        nonNotchHeight = 32
                    case .custom:
                        nonNotchHeight = 32
                    }
                    NotificationCenter.default.post(
                        name: Notification.Name.notchHeightChanged, object: nil)
                }
                if nonNotchHeightMode == .custom {
                    Slider(value: $nonNotchHeight, in: 0...40, step: 1) {
                        Text("Custom notch size - \(nonNotchHeight, specifier: "%.0f")")
                    }
                    .onChange(of: nonNotchHeight) {
                        NotificationCenter.default.post(
                            name: Notification.Name.notchHeightChanged, object: nil)
                    }
                }
                Slider(value: $nonNotchWidth, in: 120...320, step: 5) {
                    Text("Width on non-notch displays - \(nonNotchWidth, specifier: "%.0f")")
                }
                .onChange(of: nonNotchWidth) {
                    NotificationCenter.default.post(
                        name: Notification.Name.notchHeightChanged, object: nil)
                }
                if notchShapeStyle != .notch {
                    Slider(value: $islandTopGap, in: 0...20, step: 1) {
                        Text("Island gap from top edge - \(islandTopGap, specifier: "%.0f")")
                    }
                }
            } header: {
                Text("Notch sizing")
            }

            NotchBehaviour()

        }
        .toolbar {
            Button("Quit app") {
                NSApp.terminate(self)
            }
            .controlSize(.extraLarge)
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("General")
    }

    @ViewBuilder
    func NotchBehaviour() -> some View {
        Section {
            Defaults.Toggle(key: .openNotchOnHover) {
                Text("Open notch on hover")
            }
            Defaults.Toggle(key: .enableHaptics) {
                    Text("Enable haptic feedback")
            }
            Defaults.Toggle(key: .showHelloAnimationOnLaunch) {
                Text("Show hello animation on launch")
            }
            Toggle("Remember last tab", isOn: $coordinator.openLastTabByDefault)
            if openNotchOnHover {
                Slider(value: $minimumHoverDuration, in: 0...1, step: 0.1) {
                    HStack {
                        Text("Hover delay")
                        Spacer()
                        Text("\(minimumHoverDuration, specifier: "%.1f")s")
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: minimumHoverDuration) {
                    NotificationCenter.default.post(
                        name: Notification.Name.notchHeightChanged, object: nil)
                }
            }
        } header: {
            Text("Notch behavior")
        }
    }
}



struct HUD: View {
    @EnvironmentObject var vm: NotchlyViewModel
    @Default(.enableGradient) var enableGradient
    @Default(.optionKeyAction) var optionKeyAction
    @Default(.hudReplacement) var hudReplacement
    @ObservedObject var coordinator = NotchlyViewCoordinator.shared
    @State private var accessibilityAuthorized = false
    
    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .hudReplacement) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Replace system HUD")
                        Text("Replaces the standard macOS volume, display brightness and keyboard brightness HUDs with a custom design.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !accessibilityAuthorized {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("\(AccessibilityPermission.name) access is needed to replace the system HUD.", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                        Text("Turn on NotchlyXPCHelper (and Notchly, if it is listed) in System Settings > Privacy & Security > \(AccessibilityPermission.name), then switch this on.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            Button("Request Access") {
                                XPCHelperClient.shared.requestAccessibilityAuthorization()
                            }
                            Button("Open \(AccessibilityPermission.name) Settings") {
                                AccessibilityPermission.openSettings()
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }

            Section {
                Picker("Option key behaviour", selection: $optionKeyAction) {
                    ForEach(OptionKeyAction.allCases) { opt in
                        Text(opt.rawValue).tag(opt)
                    }
                }
                
                Picker("Progress bar style", selection: $enableGradient) {
                    Text("Hierarchical")
                        .tag(false)
                    Text("Gradient")
                        .tag(true)
                }
                Defaults.Toggle(key: .systemEventIndicatorUseAccent) {
                    Text("Tint progress bar with accent color")
                }
            } header: {
                Text("General")
            }
            .disabled(!hudReplacement)
            
            Section {
                Defaults.Toggle(key: .showPowerStatusNotifications) {
                    Text("Show power status notifications")
                }
            } header: {
                Text("Battery")
            }

            Section {
                Defaults.Toggle(key: .showSystemToasts) {
                    Text("Show Caps Lock and network changes")
                }
            } header: {
                Text("Indicators")
            }

            Section {
                Defaults.Toggle(key: .showOpenNotchHUDPercentage) {
                    Text("Show percentage")
                }
            } header: {
                Text("Open Notch")
            }
            .disabled(!hudReplacement)
            
            Section {
                Defaults.Toggle(key: .showClosedNotchHUDPercentage) {
                    Text("Show percentage")
                }
            } header: {
                Text("Closed Notch")
            }
            .disabled(!Defaults[.hudReplacement])
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("HUDs")
        .task {
            accessibilityAuthorized = await XPCHelperClient.shared.isAccessibilityAuthorized()
        }
        .onAppear {
            XPCHelperClient.shared.startMonitoringAccessibilityAuthorization()
        }
        .onDisappear {
            XPCHelperClient.shared.stopMonitoringAccessibilityAuthorization()
        }
        .onReceive(NotificationCenter.default.publisher(for: .accessibilityAuthorizationChanged)) { notification in
            if let granted = notification.userInfo?["granted"] as? Bool {
                accessibilityAuthorized = granted
            }
        }
    }
}

struct Media: View {
    @Default(.waitInterval) var waitInterval
    @Default(.mediaController) var mediaController
    @ObservedObject var coordinator = NotchlyViewCoordinator.shared
    @Default(.hideNotchOption) var hideNotchOption
    @Default(.enableSneakPeek) private var enableSneakPeek


    var body: some View {
        Form {
            Section {
                Picker("Music Source", selection: $mediaController) {
                    ForEach(availableMediaControllers) { controller in
                        Text(controller.rawValue).tag(controller)
                    }
                }
                .onChange(of: mediaController) { _, _ in
                    NotificationCenter.default.post(
                        name: Notification.Name.mediaControllerChanged,
                        object: nil
                    )
                }
            } header: {
                Text("Media Source")
            } footer: {
                if MusicManager.shared.isNowPlayingDeprecated {
                    HStack {
                        Text("YouTube Music requires this third-party app to be installed: ")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Link(
                            "https://github.com/pear-devs/pear-desktop",
                            destination: URL(string: "https://github.com/pear-devs/pear-desktop")!
                        )
                        .font(.caption)
                        .foregroundColor(.blue)  // Ensures it's visibly a link
                    }
                } else {
                    Text(
                        "'Now Playing' was the only option on previous versions and works with all media apps."
                    )
                    .foregroundStyle(.secondary)
                    .font(.caption)
                }
            }
            
            Section {
                Toggle(
                    "Show music live activity",
                    isOn: $coordinator.musicLiveActivityEnabled.animation()
                )
                Toggle("Show sneak peek on playback changes", isOn: $enableSneakPeek)
                HStack {
                    Stepper(value: $waitInterval, in: 0...10, step: 1) {
                        HStack {
                            Text("Media inactivity timeout")
                            Spacer()
                            Text("\(Defaults[.waitInterval], specifier: "%.0f") seconds")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Picker(
                    selection: $hideNotchOption,
                    label:
                        HStack {
                            Text("Full screen behavior")
                            customBadge(text: "Beta")
                        }
                ) {
                    Text("Hide for all apps").tag(HideNotchOption.always)
                    Text("Hide for media app only").tag(
                        HideNotchOption.nowPlayingOnly)
                    Text("Never hide").tag(HideNotchOption.never)
                }
            } header: {
                Text("Media playback live activity")
            }
            
            Section {
                Defaults.Toggle(key: .coloredSpectrogram) {
                    Text("Colored spectrogram")
                }
                Defaults.Toggle("Player tinting", key: .playerColorTinting)
                Defaults.Toggle(key: .lightingEffect) {
                    Text("Enable blur effect behind album art")
                }
            } header: {
                Text("Appearance")
            }

            Section {
                MusicSlotConfigurationView()
                Defaults.Toggle(key: .lyricsUseAlbumColor) {
                    Text("Tint lyrics with the album colour")
                }
            } header: {
                Text("Media controls")
            }  footer: {
                Text("Customize which controls appear in the music player. Volume expands when active.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Music")
    }

    // Only show controller options that are available on this macOS version
    private var availableMediaControllers: [MediaControllerType] {
        if MusicManager.shared.isNowPlayingDeprecated {
            return MediaControllerType.allCases.filter { !$0.usesNowPlaying }
        } else {
            return MediaControllerType.allCases
        }
    }
}

struct CalendarSettings: View {
    @ObservedObject private var calendarManager = CalendarManager.shared
    @Default(.hideCompletedReminders) var hideCompletedReminders
    @Default(.hideAllDayEvents) var hideAllDayEvents
    @Default(.autoScrollToNextEvent) var autoScrollToNextEvent
    @Default(.calendarEventNotifications) var calendarEventNotifications
    @Default(.calendarEventLeadMinutes) var calendarEventLeadMinutes

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .hideCompletedReminders) {
                    Text("Hide completed reminders")
                }
                Defaults.Toggle(key: .hideAllDayEvents) {
                    Text("Hide all-day events")
                }
                Defaults.Toggle(key: .autoScrollToNextEvent) {
                    Text("Auto-scroll to next event")
                }
                Defaults.Toggle(key: .showFullEventTitles) {
                    Text("Always show full event titles")
                }
            } header: {
                Text("General")
            }
            Section {
                Defaults.Toggle(key: .calendarEventNotifications) {
                    Text("Show upcoming events in the notch")
                }
                Stepper(value: $calendarEventLeadMinutes, in: 1...30) {
                    HStack {
                        Text("Remind me before")
                        Spacer()
                        Text("\(calendarEventLeadMinutes) min")
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(!calendarEventNotifications)
            } header: {
                Text("Event notifications")
            } footer: {
                Text("The closed notch shows the event's title before it starts, and again when it starts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section(header: Text("Calendars")) {
                if calendarManager.calendarAuthorizationStatus != .fullAccess {
                    Text("Calendar access is denied. Please enable it in System Settings.")
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Open Calendar Settings") {
                        if let settingsURL = URL(
                            string:
                                "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
                        ) {
                            NSWorkspace.shared.open(settingsURL)
                        }
                    }
                } else {
                    List {
                        ForEach(calendarManager.eventCalendars, id: \.id) { calendar in
                            Toggle(
                                isOn: Binding(
                                    get: { calendarManager.getCalendarSelected(calendar) },
                                    set: { isSelected in
                                        Task {
                                            await calendarManager.setCalendarSelected(
                                                calendar, isSelected: isSelected)
                                        }
                                    }
                                )
                            ) {
                                Text(calendar.title)
                            }
                            .accentColor(lighterColor(from: calendar.color))
                        }
                    }
                }
            }
            Section(header: Text("Reminders")) {
                if calendarManager.reminderAuthorizationStatus != .fullAccess {
                    Text("Reminder access is denied. Please enable it in System Settings.")
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Open Reminder Settings") {
                        if let settingsURL = URL(
                            string:
                                "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders"
                        ) {
                            NSWorkspace.shared.open(settingsURL)
                        }
                    }
                } else {
                    List {
                        ForEach(calendarManager.reminderLists, id: \.id) { calendar in
                            Toggle(
                                isOn: Binding(
                                    get: { calendarManager.getCalendarSelected(calendar) },
                                    set: { isSelected in
                                        Task {
                                            await calendarManager.setCalendarSelected(
                                                calendar, isSelected: isSelected)
                                        }
                                    }
                                )
                            ) {
                                Text(calendar.title)
                            }
                            .accentColor(lighterColor(from: calendar.color))
                        }
                    }
                }
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Calendar")
        .onAppear {
            Task {
                await calendarManager.checkCalendarAuthorization()
                await calendarManager.checkReminderAuthorization()
            }
        }
    }
}

func lighterColor(from nsColor: NSColor, amount: CGFloat = 0.14) -> Color {
    let srgb = nsColor.usingColorSpace(.sRGB) ?? nsColor
    var (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0,0,0,0)
    srgb.getRed(&r, green: &g, blue: &b, alpha: &a)

    func lighten(_ c: CGFloat) -> CGFloat {
        let increased = c + (1.0 - c) * amount
        return min(max(increased, 0), 1)
    }

    let nr = lighten(r)
    let ng = lighten(g)
    let nb = lighten(b)

    return Color(red: Double(nr), green: Double(ng), blue: Double(nb), opacity: Double(a))
}

struct About: View {
    let updaterController: SPUStandardUpdaterController
    @State private var document: AboutDocument?

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Notchly"
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 6) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 96, height: 96)
                    Text(appName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Version \(Bundle.main.releaseVersionNumber ?? "") (\(Bundle.main.buildVersionNumber ?? ""))")
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section {
                Button("Check for Updates…") {
                    updaterController.updater.checkForUpdates()
                }
                .disabled(!updaterController.updater.canCheckForUpdates)
                aboutRow("Release Notes", systemImage: "doc.text") { document = .releaseNotes }
                AutomaticUpdateToggles(updater: updaterController.updater)
            }

            Section {
                aboutRow("Privacy Policy", systemImage: "hand.raised") { document = .privacyPolicy }
                aboutRow("Terms of Use", systemImage: "doc.plaintext") { document = .termsOfUse }
            }

            Section {
                aboutRow("Request a Feature", systemImage: "lightbulb", external: true) {
                    NSWorkspace.shared.open(AppLinks.requestFeature)
                }
                aboutRow("Report a Bug", systemImage: "ladybug", external: true) {
                    NSWorkspace.shared.open(AppLinks.reportBug)
                }
                aboutRow("Star on GitHub", systemImage: "star", external: true) {
                    NSWorkspace.shared.open(AppLinks.repository)
                }
            }
        }
        .sheet(item: $document) { document in
            AboutDocumentSheet(document: document)
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("About")
    }

    private func aboutRow(_ title: String, systemImage: String, external: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Image(systemName: external ? "arrow.up.right" : "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// "Check for updates automatically" and "Install updates automatically", kept in step with Sparkle.
private struct AutomaticUpdateToggles: View {
    let updater: SPUUpdater
    @State private var checks: Bool
    @State private var installs: Bool

    init(updater: SPUUpdater) {
        self.updater = updater
        _checks = State(initialValue: updater.automaticallyChecksForUpdates)
        _installs = State(initialValue: updater.automaticallyDownloadsUpdates)
    }

    var body: some View {
        Toggle("Check for updates automatically", isOn: $checks)
            .onChange(of: checks) { _, value in updater.automaticallyChecksForUpdates = value }
        Toggle("Install updates automatically", isOn: $installs)
            .disabled(!checks)
            .onChange(of: installs) { _, value in updater.automaticallyDownloadsUpdates = value }
    }
}

struct Shelf: View {
    
    @Default(.shelfTapToOpen) var shelfTapToOpen: Bool
    @Default(.quickShareProvider) var quickShareProvider
    @Default(.expandedDragDetection) var expandedDragDetection: Bool
    @StateObject private var quickShareService = QuickShareService.shared

    private var selectedProvider: QuickShareProvider? {
        quickShareService.availableProviders.first(where: { $0.id == quickShareProvider })
    }
    
    init() {
        Task { await QuickShareService.shared.discoverAvailableProviders() }
    }
    
    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .openShelfByDefault) {
                    Text("Open shelf by default if items are present")
                }
                Defaults.Toggle(key: .expandedDragDetection) {
                    Text("Expanded drag detection area")
                }
                .onChange(of: expandedDragDetection) {
                    NotificationCenter.default.post(
                        name: Notification.Name.expandedDragDetectionChanged,
                        object: nil
                    )
                }
                Defaults.Toggle(key: .copyOnDrag) {
                    Text("Copy items on drag")
                }
                Defaults.Toggle(key: .autoRemoveShelfItems) {
                    Text("Remove from shelf after dragging")
                }

            } header: {
                HStack {
                    Text("General")
                }
            }
            
            Section {
                Picker("Quick Share Service", selection: $quickShareProvider) {
                    ForEach(quickShareService.availableProviders, id: \.id) { provider in
                        HStack {
                            Group {
                                if let imgData = provider.imageData, let nsImg = NSImage(data: imgData) {
                                    Image(nsImage: nsImg)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                } else {
                                    Image(systemName: "square.and.arrow.up")
                                }
                            }
                            .frame(width: 16, height: 16)
                            .foregroundColor(.accentColor)
                            Text(provider.id)
                        }
                        .tag(provider.id)
                    }
                }
                .pickerStyle(.menu)
                
                if let selectedProvider = selectedProvider {
                    HStack {
                        Group {
                            if let imgData = selectedProvider.imageData, let nsImg = NSImage(data: imgData) {
                                Image(nsImage: nsImg)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                        .frame(width: 16, height: 16)
                        .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Currently selected: \(selectedProvider.id)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Files dropped on the shelf will be shared via this service")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                // Providers are always enabled; user can pick default service above.
                
            } header: {
                HStack {
                    Text("Quick Share")
                }
            } footer: {
                Text("Choose which service to use when sharing files from the shelf. Click the shelf button to select files, or drag files onto it to share immediately.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Shelf")
    }
}


struct Advanced: View {
    @Default(.useCustomAccentColor) var useCustomAccentColor
    @Default(.customAccentColorData) var customAccentColorData
    @Default(.extendHoverArea) var extendHoverArea
    @Default(.showOnLockScreen) var showOnLockScreen
    @Default(.hideFromScreenRecording) var hideFromScreenRecording
    
    @State private var customAccentColor: Color = .accentColor
    @State private var selectedPresetColor: PresetAccentColor? = nil
    @Default(.appIconChoice) var appIconChoice
    
    // macOS accent colors
    enum PresetAccentColor: String, CaseIterable, Identifiable {
        case blue = "Blue"
        case purple = "Purple"
        case pink = "Pink"
        case red = "Red"
        case orange = "Orange"
        case yellow = "Yellow"
        case green = "Green"
        case graphite = "Graphite"
        
        var id: String { self.rawValue }
        
        var color: Color {
            switch self {
            case .blue: return Color(red: 0.0, green: 0.478, blue: 1.0)
            case .purple: return Color(red: 0.686, green: 0.322, blue: 0.871)
            case .pink: return Color(red: 1.0, green: 0.176, blue: 0.333)
            case .red: return Color(red: 1.0, green: 0.271, blue: 0.227)
            case .orange: return Color(red: 1.0, green: 0.584, blue: 0.0)
            case .yellow: return Color(red: 1.0, green: 0.8, blue: 0.0)
            case .green: return Color(red: 0.4, green: 0.824, blue: 0.176)
            case .graphite: return Color(red: 0.557, green: 0.557, blue: 0.576)
            }
        }
    }
    
    var body: some View {
        Form {
            Section {
                HStack {
                    Button("Export Settings…") {
                        SettingsTransfer.exportSettings()
                    }
                    Button("Import Settings…") {
                        SettingsTransfer.importSettings()
                    }
                }
            } header: {
                Text("Backup")
            } footer: {
                Text("Saves your settings to a file, to keep a backup or move them to another Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                VStack(alignment: .leading, spacing: 16) {
                    // Toggle between system and custom
                    Picker("Accent color", selection: $useCustomAccentColor) {
                        Text("System").tag(false)
                        Text("Custom").tag(true)
                    }
                    .pickerStyle(.segmented)
                    
                    if !useCustomAccentColor {
                        // System accent info
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                AccentCircleButton(
                                    isSelected: true,
                                    color: .accentColor,
                                    isSystemDefault: true
                                ) {}
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Using System Accent")
                                        .font(.body)
                                    Text("Your macOS system accent color")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    } else {
                        // Custom color options
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Color Presets")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 12) {
                                ForEach(PresetAccentColor.allCases) { preset in
                                    AccentCircleButton(
                                        isSelected: selectedPresetColor == preset,
                                        color: preset.color,
                                        isMulticolor: false
                                    ) {
                                        selectedPresetColor = preset
                                        customAccentColor = preset.color
                                        saveCustomColor(preset.color)
                                        forceUiUpdate()
                                    }
                                }
                                Spacer()
                            }
                            
                            Divider()
                                .padding(.vertical, 4)
                            
                            // Custom color picker
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Pick a Color")
                                        .font(.body)
                                    Text("Choose any color")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                ColorPicker(selection: Binding(
                                    get: { customAccentColor },
                                    set: { newColor in
                                        customAccentColor = newColor
                                        selectedPresetColor = nil
                                        saveCustomColor(newColor)
                                        forceUiUpdate()
                                    }
                                ), supportsOpacity: false) {
                                    ZStack {
                                        Circle()
                                            .fill(customAccentColor)
                                            .frame(width: 32, height: 32)
                                        
                                        if selectedPresetColor == nil {
                                            Circle()
                                                .strokeBorder(.primary.opacity(0.3), lineWidth: 2)
                                                .frame(width: 32, height: 32)
                                        }
                                    }
                                }
                                .labelsHidden()
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Accent color")
            } footer: {
                Text("Choose between your system accent color or customize it with your own selection.")
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .onAppear {
                initializeAccentColorState()
            }
            
            Section {
                Defaults.Toggle(key: .enableShadow) {
                    Text("Enable window shadow")
                }
                Defaults.Toggle(key: .cornerRadiusScaling) {
                    Text("Corner radius scaling")
                }
            } header: {
                Text("Window Appearance")
            }
            
            Section {
                HStack {
                    ForEach(AppIconOption.all) { option in
                        Spacer()
                        VStack {
                            Image(option.asset)
                                .resizable()
                                .frame(width: 72, height: 72)
                                .background(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .strokeBorder(option.id == appIconChoice ? Color.effectiveAccent : .clear, lineWidth: 2.5)
                                )
                            Text(option.name)
                                .fontWeight(.medium)
                                .font(.caption)
                                .foregroundStyle(option.id == appIconChoice ? .white : .secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(option.id == appIconChoice ? Color.effectiveAccent : .clear))
                        }
                        .onTapGesture {
                            withAnimation { appIconChoice = option.id }
                            option.apply()
                        }
                        Spacer()
                    }
                }
            } header: {
                Text("App icon")
            }

            Section {
                Defaults.Toggle(key: .extendHoverArea) {
                    Text("Extend hover area")
                }
                Defaults.Toggle(key: .hideTitleBar) {
                    Text("Hide title bar")
                }
                Defaults.Toggle(key: .showCallIndicator) {
                    Text("Show FaceTime and phone calls in the notch")
                }
                Defaults.Toggle(key: .showOnLockScreen) {
                    Text("Show notch on lock screen")
                }
                Defaults.Toggle(key: .showLockScreenAnimation) {
                    Text("Show lock and unlock animation")
                }
                Defaults.Toggle(key: .playLockScreenSounds) {
                    Text("Play lock and unlock sounds")
                }
                Defaults.Toggle(key: .showAccessoryConnectedIndicator) {
                    Text("Show when accessories connect")
                }
                Defaults.Toggle(key: .hideFromScreenRecording) {
                    Text("Hide from screen recording")
                }
            } header: {
                Text("Window Behavior")
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Advanced")
        .onAppear {
            loadCustomColor()
        }
    }
    
    private func forceUiUpdate() {
        // Force refresh the UI
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("AccentColorChanged"), object: nil)
        }
    }
    
    private func saveCustomColor(_ color: Color) {
        let nsColor = NSColor(color)
        if let colorData = try? NSKeyedArchiver.archivedData(withRootObject: nsColor, requiringSecureCoding: false) {
            Defaults[.customAccentColorData] = colorData
            forceUiUpdate()
        }
    }
    
    private func loadCustomColor() {
        if let colorData = Defaults[.customAccentColorData],
           let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: colorData) {
            customAccentColor = Color(nsColor: nsColor)
            
            // Check if loaded color matches a preset
            selectedPresetColor = nil
            for preset in PresetAccentColor.allCases {
                if colorsAreEqual(Color(nsColor: nsColor), preset.color) {
                    selectedPresetColor = preset
                    break
                }
            }
        }
    }
    
    private func colorsAreEqual(_ color1: Color, _ color2: Color) -> Bool {
        let nsColor1 = NSColor(color1).usingColorSpace(.sRGB) ?? NSColor(color1)
        let nsColor2 = NSColor(color2).usingColorSpace(.sRGB) ?? NSColor(color2)
        
        return abs(nsColor1.redComponent - nsColor2.redComponent) < 0.01 &&
               abs(nsColor1.greenComponent - nsColor2.greenComponent) < 0.01 &&
               abs(nsColor1.blueComponent - nsColor2.blueComponent) < 0.01
    }
    
    private func initializeAccentColorState() {
        if !useCustomAccentColor {
            selectedPresetColor = nil // Multicolor is selected when useCustomAccentColor is false
        } else {
            loadCustomColor()
        }
    }
}

// MARK: - Accent Circle Button Component
struct AccentCircleButton: View {
    let isSelected: Bool
    let color: Color
    var isSystemDefault: Bool = false
    var isMulticolor: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Color circle
                Circle()
                    .fill(color)
                    .frame(width: 32, height: 32)
                
                // Subtle border
                Circle()
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    .frame(width: 32, height: 32)
                
                // Apple-style highlight ring around the middle when selected
                if isSelected {
                    Circle()
                        .strokeBorder(
                            Color.white.opacity(0.5),
                            lineWidth: 2
                        )
                        .frame(width: 28, height: 28)
                }
            }
        }
        .buttonStyle(.plain)
        .help(isSystemDefault ? "Use your macOS system accent color" : "")
    }
}

struct Shortcuts: View {
    @Default(.keyboardShortcutsEnabled) var keyboardShortcutsEnabled

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .keyboardShortcutsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable keyboard shortcuts")
                        Text("Turns off every Notchly shortcut without clearing them.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Group {
                Section {
                    KeyboardShortcuts.Recorder("Open or close the notch", name: .toggleNotchOpen)
                    KeyboardShortcuts.Recorder("Open the floating shelf", name: .toggleFloatingShelf)
                    KeyboardShortcuts.Recorder("Search the clipboard", name: .clipboardHistoryPanel)
                } header: {
                    Text("Notch")
                }

                Section {
                    KeyboardShortcuts.Recorder("Previous track", name: .musicPreviousTrack)
                    KeyboardShortcuts.Recorder("Next track", name: .musicNextTrack)
                    KeyboardShortcuts.Recorder("Show what's playing", name: .toggleSneakPeek)
                } header: {
                    Text("Music")
                } footer: {
                    Text("Previous and next default to ⌃< and ⌃> (the comma and period keys).")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                Section {
                    KeyboardShortcuts.Recorder("Approve", name: .agentApprove)
                    KeyboardShortcuts.Recorder("Deny", name: .agentDeny)
                    KeyboardShortcuts.Recorder("Jump to terminal", name: .agentJumpToTerminal)
                } header: {
                    HStack {
                        Text("AI Integrations")
                        customBadge(text: "Beta")
                    }
                } footer: {
                    Text("Only active while an agent is waiting for you, so they don't get in the way of other apps.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
            .disabled(!keyboardShortcutsEnabled)
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Shortcuts")
    }
}

func proFeatureBadge() -> some View {
    Text("Upgrade to Pro")
        .foregroundStyle(Color(red: 0.545, green: 0.196, blue: 0.98))
        .font(.footnote.bold())
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 4).stroke(
                Color(red: 0.545, green: 0.196, blue: 0.98), lineWidth: 1))
}

func comingSoonTag() -> some View {
    Text("Coming soon")
        .foregroundStyle(.secondary)
        .font(.footnote.bold())
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(Color(nsColor: .secondarySystemFill))
        .clipShape(.capsule)
}

func customBadge(text: String) -> some View {
    Text(text)
        .foregroundStyle(.secondary)
        .font(.footnote.bold())
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(Color(nsColor: .secondarySystemFill))
        .clipShape(.capsule)
}

func warningBadge(_ text: String, _ description: String) -> some View {
    Section {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.yellow)
            VStack(alignment: .leading) {
                Text(text)
                    .font(.headline)
                Text(description)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

#Preview {
    HUD()
}

/// Which tabs the open notch has, their order, and what Home shows.
struct TabsSettings: View {
    @Default(.homeLeftPane) var homeLeftPane
    @Default(.homeRightPane) var homeRightPane
    @Default(.tabOrder) var tabOrder
    @Default(.hiddenTabs) var hiddenTabs
    @Default(.showCalendar) var showCalendar
    @Default(.notchlyShelf) var notchlyShelf
    @Default(.agentIntegrationEnabled) var agentIntegrationEnabled
    @Default(.showMirror) var showMirror

    private var hasVideoInput: Bool { AVCaptureDevice.default(for: .video) != nil }

    var body: some View {
        Form {
            Section {
                Picker("Home left", selection: $homeLeftPane) {
                    ForEach(HomePane.allCases) { pane in
                        Text(pane.rawValue).tag(pane)
                    }
                }
                Picker("Home right", selection: $homeRightPane) {
                    ForEach(HomePane.allCases) { pane in
                        Text(pane.rawValue).tag(pane)
                    }
                }
                let order = Array(orderedTabViews.dropFirst())
                HStack {
                    Label(NotchViews.home.title, systemImage: NotchViews.home.icon)
                    Spacer()
                    Text("Always first")
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(order.enumerated()), id: \.element) { index, view in
                    HStack {
                        Label(view.title, systemImage: view.icon)
                        if view == .agents {
                            customBadge(text: "Beta")
                        }
                        Spacer()
                        Toggle("Show", isOn: visibility(of: view))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .help("Show or hide this tab")
                        Button {
                            moveTab(at: index, by: -1, in: order)
                        } label: {
                            Image(systemName: "chevron.up")
                        }
                        .disabled(index == 0)
                        Button {
                            moveTab(at: index, by: 1, in: order)
                        } label: {
                            Image(systemName: "chevron.down")
                        }
                        .disabled(index == order.count - 1)
                    }
                    .buttonStyle(.borderless)
                }
                HStack {
                    Label("Mirror", systemImage: "web.camera")
                    Spacer()
                    Text("Always last")
                        .foregroundStyle(.secondary)
                    Toggle("Show", isOn: $showMirror)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .disabled(!hasVideoInput)
                        .help(hasVideoInput ? "Show the mirror button" : "No camera found")
                }
            } header: {
                Text("Tabs")
            }

            Section {
                Defaults.Toggle(key: .showNotchPet) {
                    Text("Show a pet in the closed notch while inactive")
                }
            } header: {
                Text("Pet")
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Tabs & Home")
    }

    private func moveTab(at index: Int, by offset: Int, in order: [NotchViews]) {
        var order = order
        let target = index + offset
        guard order.indices.contains(index), order.indices.contains(target) else { return }
        order.swapAt(index, target)
        tabOrder = order
    }

    /// Calendar, Shelf and AI Agents are switched here and nowhere else; the other tabs are just hidden.
    private func visibility(of view: NotchViews) -> Binding<Bool> {
        switch view {
        case .calendar: return $showCalendar
        case .shelf: return $notchlyShelf
        case .agents: return $agentIntegrationEnabled
        default: break
        }
        return Binding(
            get: { !hiddenTabs.contains(view) },
            set: { show in
                hiddenTabs.removeAll { $0 == view }
                if !show {
                    hiddenTabs.append(view)
                }
            }
        )
    }


}
