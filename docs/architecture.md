# Architecture

Notchly is a SwiftUI app hosted in AppKit panels. One borderless panel per display draws the notch (or a floating "island" on displays without a notch). Everything the user sees is a SwiftUI view inside that panel.

Facts below come from `Notchly/` and `NotchlyXPCHelper/`. See also [features.md](features.md) and [ai-integrations.md](ai-integrations.md).

## Targets

Defined in `Notchly.xcodeproj` (bundle id `com.cmxau.notchly`, `MARKETING_VERSION` 2.7.3 at the time of writing):

| Target | Bundle id | Notes |
| --- | --- | --- |
| Notchly (app) | `com.cmxau.notchly` | Sandboxed (see `Notchly/Notchly.entitlements`). Sources are in `Notchly/`. |
| NotchlyXPCHelper | `com.cmxau.notchly.NotchlyXPCHelper` | XPC service, **not** sandboxed (`NotchlyXPCHelper.entitlements` sets `app-sandbox` to false). Sources in `NotchlyXPCHelper/`. |

The project uses file-system synchronized groups, so files added to a folder are compiled without editing the project file.

## Main data flow

```
                       +-----------------------------+
 System events ------->|  Managers (Notchly/managers)|
 (battery, volume,     |  Music, Calendar, Battery,  |
  brightness, BT,      |  Volume, Brightness, Webcam |
  downloads, calls)    +--------------+--------------+
                                      |  @Published state / Notification
 Agent CLIs --hook--> notchly-agent-hook.sh
                         | HTTP POST 127.0.0.1 + token
                         v
                 AgentBridgeServer --> AgentHub (sessions, pending requests)
                                      |
                                      v
 +--------------------+     +-------------------------+
 | NotchlyViewCoordinator|<->| NotchlyViewModel (per   |
 | (singleton: current|     | display: open/closed,   |
 | tab, sneak peek,   |     | size, hover, drag)      |
 | live activity state)|    +------------+------------+
 +---------+----------+                  |
           |  Defaults[...] (UserDefaults, observed)
           v                              v
     +---------------------------------------------+
     | ContentView  (closed state / open state)    |
     |  closed: live activity + sneak peek         |
     |  open:   header + tab content               |
     +----------------------+----------------------+
                            | NSHostingView
                            v
     NotchlySkyLightWindow (NSPanel) per display, positioned at top centre
                            |
        privileged work     v
   App --NSXPCConnection--> NotchlyXPCHelper (accessibility, brightness,
                            agent config files, ssh/terminal stubs)
```

## Windowing

- `NotchlyApp.swift`: `DynamicNotchApp` is the `@main` entry. Its `Settings` scene is an `EmptyView`; there is no menu bar icon. Settings open from the gear in the notch or by right-clicking the notch (`NotchlyViewCoordinator`, `SettingsWindowController`). `AppDelegate` does the real work.
- `AppDelegate.createNotchlyWindow(for:with:)` builds a `NotchlySkyLightWindow` (subclass of the `NotchlyWindow` panel, `components/Notch/`), hosts `ContentView` in an `NSHostingView`, and inserts the window into a private Space (`managers/NotchSpaceManager.swift`, `private/CGSSpace.swift`) so it stays above other windows. When the screen is locked, the SkyLight library (`SkyLightWindow` package) is used to keep it visible on the lock screen.
- One window and one `NotchlyViewModel` per display when "Show on all displays" is on (`windows` / `viewModels` dictionaries keyed by display UUID). `screenConfigurationDidChange` and `adjustWindowPosition` reposition windows when displays change.
- Drag detectors (`observers/DragDetector.swift`) open the notch when a file is dragged near it.
- Notchless displays use the "floating" shape (`NotchShapeStyle`) with width and top gap from Settings.

## View model and coordinator

- `NotchlyViewModel` (`models/`): per-display state. `notchState` (`.closed` / `.open`), sizes, hover and drop targeting, camera preview toggle. `open()` and `close()` change state.
- `NotchlyViewCoordinator` (`NotchlyViewCoordinator.swift`): app-wide singleton. Holds `currentView` (a `NotchViews` value), the sneak-peek state (`SneakContentType`: brightness, volume, backlight, music, mic, battery, download), the expanding-view state, lock-screen and accessory indicators, selected/preferred display, and `@AppStorage` flags such as `firstLaunch`.

## Tabs

`NotchViews` (`enums/generic.swift`) lists the tabs: `home`, `music`, `calendar`, `agents`, `shelf`, `teleprompter`, `clipboard`, `timer`, `weather`. `Defaults[.tabOrder]` and `Defaults[.hiddenTabs]` control order and visibility; `homeLeftPane` / `homeRightPane` (`HomePane`) choose what the Home tab shows. Tab buttons live in `components/Tabs/`; tab content is switched in `ContentView.NotchLayout()`.

## Live activities and closed-notch states

`ContentView` draws the closed notch and picks the highest-priority activity. Functions in `ContentView.swift`: `LockIndicatorActivity`, `AccessoryConnectedActivity`, `CallActivity`, `ToastActivity`, `TimerActivity`, `CalendarEventActivity`, `AgentLiveActivity`, `NotchPetActivity`, `MusicLiveActivity`. HUD replacements (volume, brightness, keyboard backlight) and battery/download indicators are in `components/Live activities/`. The exact priority order is defined in `ContentView.body`; read it there rather than relying on this list.

## Settings and Defaults persistence

- Settings UI: `components/Settings/SettingsView.swift` (a `NavigationSplitView`; pages listed in [features.md](features.md)), plus `Settings/Agents/` and `private/ToolsSettings.swift`, `private/Teleprompter.swift` (`TeleprompterSettings`).
- Persistence uses the [Defaults](https://github.com/sindresorhus/Defaults) package. Keys are declared as `Defaults.Keys` in `models/Constants.swift`; some features declare their own keys next to their code (for example `private/Clipboard.swift`, `private/Weather.swift`, `private/StatusToast.swift`). Values are stored in UserDefaults under `com.cmxau.notchly`.
- `SettingsTransfer.swift` exports and imports the defaults domain as a plist (see [security.md](security.md) for what is excluded).
- Global shortcuts use the `KeyboardShortcuts` package; names are declared in `Shortcuts/ShortcutConstants.swift` and `Shortcuts/AppShortcutsController.swift`.

## XPC helper

`NotchlyXPCHelper` exists because the app is sandboxed. The app talks to it through `XPCHelperClient/` (`NSXPCConnection`, wrapped with `AsyncXPCConnection`). The protocol (`NotchlyXPCHelperProtocol.swift`, duplicated in the app and the helper) covers:

- Accessibility authorization checks and prompts.
- Keyboard and screen brightness read/write.
- Reading, writing and checking an allowlisted set of files in the real home folder (`AgentFiles.swift`, gated by `AgentFileAllowlist.swift`).
- SSH tunnel, remote file, terminal-pane and Claude usage calls. In the current source these are stubs that reply "Not implemented yet" (`SSHTunnels.swift`, `TerminalPanes.swift`, `AgentUsage.swift`); the matching settings sections are empty views.

## Agent bridge

`Notchly/agents/`: `AgentBridgeServer` (loopback HTTP), `AgentHub` (sessions and pending approvals, published to the UI), `AgentRegistry` (list of `AgentIntegration` types), `AgentIntegrationInstaller` (edits agent config through the XPC helper), `AgentCatalog` (the list shown in Settings), `TerminalJumper`, `AgentSoundPlayer`, and the shell script `notchly-agent-hook.sh`. Details in [ai-integrations.md](ai-integrations.md).

## Media controllers

`MediaControllers/` implements `MediaControllerProtocol` for Apple Music, Spotify, YouTube Music (local HTTP/WebSocket client), generic app now-playing, and system Now Playing (via the bundled `mediaremote-adapter`). `managers/MusicManager.swift` selects the controller from `Defaults[.mediaController]` and publishes `PlaybackState`. `managers/SystemAudioSpectrum.swift` taps system output for the equaliser (Core Audio process tap).

## Shelf

`components/Shelf/`: `Models` (`ShelfItem`, `Bookmark`), `Services` (drop handling, persistence, thumbnails, Quick Look, share services, temporary file storage), `ViewModels`, `Views`. Items are held as files/bookmarks; `private/FloatingShelf.swift` shows the shelf in its own always-on-top panel.

## The `private/` convention

`Notchly/private/` holds the Notchly-specific features added on top of upstream: Teleprompter, Clipboard, FocusTimer, Weather, StatusToast, CallMonitor, FloatingShelf, ToolsSettings, OnboardingFeatures, plus shared helpers (`NotchTabStyle.swift`, `CGSSpace.swift`). Their file headers say "Lives in `private/` because that folder is auto-included in the Xcode target": the folder is a synchronized group, so new files there build with no project edit. "private" refers to this convention, not to access control. (Not verified: whether the folder is meant to be excluded from upstream merges.)

## Source tree map

```
Notchly.xcodeproj/        Xcode project, Package.resolved (SwiftPM)
Notchly/
  NotchlyApp.swift        @main, AppDelegate, windows, onboarding launch
  ContentView.swift       closed/open notch UI, live activities
  NotchlyViewCoordinator.swift  app-wide state
  models/                 NotchlyViewModel, Constants (Defaults keys), playback, calendar, battery
  enums/ extensions/ helpers/ utils/ sizing/   shared helpers
  managers/               system integrations (music, calendar, battery, volume, brightness, webcam, ...)
  observers/              drag detection, media keys, fullscreen detection
  MediaControllers/       Apple Music, Spotify, YouTube Music, now-playing
  components/
    Notch/ Tabs/ Live activities/ Music/ Calendar/ Shelf/ Webcam/ Tips/
    Settings/ (+ Agents/)  Onboarding/  Agents/ (tab UI)
  agents/                 bridge server, hub, registry, catalog, integrations/, hook script, icons
  private/                Teleprompter, Clipboard, Timer, Weather, toasts, call monitor, floating shelf
  Shortcuts/              global shortcut names and controller
  XPCHelperClient/        app side of the XPC connection
  menu/ metal/ animations/ pets/ sounds/ accessories/   assets and small UI
  Localizable.xcstrings   string catalog
  Info.plist, Notchly.entitlements
NotchlyXPCHelper/         unsandboxed XPC service
mediaremote-adapter/      bundled framework and script for system Now Playing
Configuration/dmg/        DMG build (dmgbuild)
scripts/                  asset preparation (pet clips, accessory clips)
updater/appcast.xml       Sparkle appcast template
.github/                  workflows, scripts, tests, templates
```

## Dependencies

From `Package.resolved`: AsyncXPCConnection, Defaults, KeyboardShortcuts, LaunchAtLogin-Modern, MacroVisionKit, Pow, SkyLightWindow, Sparkle, swift-collections, swift-syntax, SwiftUI-Introspect. Licences: [THIRD_PARTY_LICENSES](../THIRD_PARTY_LICENSES).
