# Features

Settings open from the gear in the open notch or by right-clicking the notch. The sidebar (`components/Settings/SettingsView.swift`) has three groups. Defaults key names are given so you can find them in code ([contributing.md](contributing.md)).

## Settings > Notch

### General (`GeneralSettings`)
- Launch at login.
- Show on all displays (`showOnAllDisplays`), preferred display, automatically switch display (`automaticallySwitchDisplay`).
- Shape (`notchShapeStyle`: notch or floating island) and open-notch background (`notchBackgroundStyle`).
- Notch height on notch and non-notch displays (`notchHeightMode`, `nonNotchHeightMode`, sliders), island width (`nonNotchWidth`) and top gap (`islandTopGap`).
- Open notch on hover (`openNotchOnHover`), minimum hover duration, haptics, hello animation on launch, remember last tab.

### HUDs (`HUD`)
- Replace the system volume / display brightness / keyboard brightness HUD (`hudReplacement`; needs Accessibility, called Device Control and Data Access on macOS 27, see [installation.md](installation.md#permissions)).
- Progress bar style and accent tint, percentage in the open and closed notch, option-key behaviour (`optionKeyAction`).
- Battery: power status notifications. Indicators: Caps Lock and network change toasts (`showSystemToasts`).

### Tabs & Home (`TabsSettings`)
- Which panes the Home tab shows on the left and right (`homeLeftPane`, `homeRightPane`: None, Music, Calendar, AI Agents).
- Show/hide and reorder tabs (`hiddenTabs`, `tabOrder`).
- Mirror (camera preview) toggle (`showMirror`) and the notch pet (`showNotchPet`).

## Settings > Features

### AI Integrations (`AgentsSettings`, marked Beta)
Connect or disconnect each supported tool; behaviour toggles (open the notch when an agent needs you, show agent activity in the closed notch, hand unanswered requests back to the terminal after 1/5/15 minutes or never), sounds. Remote (SSH), usage and terminal-jump sections are empty in the current source. Full detail: [ai-integrations.md](ai-integrations.md).

### Calendar (`CalendarSettings`)
Hide completed reminders, hide all-day events, auto-scroll to the next event, full event titles, event notifications with lead time (`calendarEventNotifications`, `calendarEventLeadMinutes`), and per-calendar / per-reminder-list selection. The Calendar tab and Home pane show the events; the closed notch shows an upcoming-event alert.

### Music (`Media`)
Music source (`mediaController`: Apple Music, Spotify, YouTube Music, Now Playing, Amazon Music, SoundCloud), sneak peek on playback changes, shuffle/repeat buttons, configurable control slots (`musicControlSlots`), coloured spectrogram, player tinting, lighting effect, lyrics colour from album art. Closed notch shows a live activity with album art and a real equaliser when system audio capture is allowed.

### Shelf (`Shelf`)
Drop files on the notch to hold them; open shelf by default, expanded drag detection area, copy on drag, remove after dragging, and a Quick Share provider. A floating always-on-top shelf opens with Option-Cmd-S.

### Teleprompter (`TeleprompterSettings`, `private/Teleprompter.swift`)
Script text shown in the open notch with three guidance modes: word tracking (speech recognition), classic auto-scroll, voice-activated scroll; speed slider. Uses the microphone and speech recognition. Modelled on [textream](https://github.com/f/textream) (MIT).

### Tools (`private/ToolsSettings.swift`)
- Clipboard: keep clipboard history (`clipboardHistoryEnabled`), "Clear history (keeps favourites)". Text only, stored on this Mac, skips password-manager items. Cmd-Shift-C opens a search window. See [security.md](security.md#clipboard-history).
- Timer: focus and break lengths (`focusMinutes`, `breakMinutes`), Pomodoro rounds back to back; the closed notch shows time left.
- Weather: city (press Return) and Fahrenheit (`weatherCity`, `weatherFahrenheit`). Open-Meteo, now plus next hours.

## Settings > App

### About
Version, Check for Updates, automatic check/install toggles, links to request a feature, report a bug, and the repository, and documents/release notes.

### Advanced
- Backup: Export Settings / Import Settings (plist).
- Accent colour: system or custom.
- Window appearance: shadow, corner radius scaling. App icon choice (`appIconChoice`).
- Window behaviour: extend hover area, hide title bar, show FaceTime and phone calls in the notch (`showCallIndicator`), show notch on the lock screen, lock/unlock animation and sounds, accessory-connected indicator, hide from screen recording.

### Shortcuts
Master switch (`keyboardShortcutsEnabled`) plus recorders for these defaults (from `Shortcuts/` and `private/`):

| Action | Default |
| --- | --- |
| Toggle notch open | Cmd-Shift-I |
| Toggle sneak peek | Cmd-Shift-H |
| Clipboard search window | Cmd-Shift-C |
| Floating shelf | Option-Cmd-S |
| Music previous / next | Ctrl-, and Ctrl-. |
| Approve / deny / jump to terminal (only while an agent is waiting) | Ctrl-Y, Ctrl-N, Ctrl-T |
| Toggle microphone, backlight down/up | Declared in `ShortcutConstants.swift` (Fn-F5, Cmd-F1, Cmd-F2) but not shown on the Shortcuts page as read |

## Things the notch shows without a setting page

Lock/unlock indicator, accessory connections (AirPods and other Bluetooth devices, with artwork videos in `Notchly/accessories`), downloads (`enableDownloadListener`, Safari option), battery and charging, microphone status, the notch pet (GIFs in `Notchly/pets`), and the "What's New" window. See [architecture.md](architecture.md#live-activities-and-closed-notch-states).

## Onboarding

First launch shows a feature picker (Music, Calendar, Shelf, AI agents, Clipboard, Timer, Weather, Teleprompter, Notch pet, Live alerts) that sets the matching defaults, then permission steps. Source: `components/Onboarding/`, `private/OnboardingFeatures.swift`.

Helper views for an "Upgrade to Pro" / "Coming soon" badge exist in `SettingsView.swift`; they are leftovers from upstream and no Pro tier is documented here.
