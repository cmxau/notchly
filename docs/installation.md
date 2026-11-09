# Installation

## Requirements

- macOS 14 (Sonoma) or later. This is the `MACOSX_DEPLOYMENT_TARGET` (14.0) in `Notchly.xcodeproj` and what the root [README.md](../README.md) states. Some features need newer systems; for example the equaliser uses a Core Audio process tap that needs macOS 14.2 or later and otherwise falls back to an animation.
- A Mac with a notch gives the native look; other Macs get a floating island (see [features.md](features.md)).
- Not verified: separate Apple Silicon / Intel support. The project settings do not state it.

## Install from a release DMG

1. Download the latest `.dmg` from [Releases](https://github.com/cmxau/notchly/releases/latest).
2. Open it and drag Notchly to Applications.
3. Clear the quarantine flag once (the Gatekeeper step below), then launch Notchly.

### Gatekeeper / quarantine

Release builds are not notarized yet (per the root README), so macOS blocks the first launch with an "unidentified developer" warning. Either:

```bash
xattr -dr com.apple.quarantine "/Applications/Notchly.app"
```

or right-click Notchly in Applications, choose Open, and confirm. The alpha workflow's release notes give the same two options for its ad-hoc signed builds.

### Homebrew

Notchly is in the [`cmxau/homebrew-notchly`](https://github.com/cmxau/homebrew-notchly) tap:

```bash
brew tap cmxau/notchly
brew trust cmxau/notchly
brew install --cask notchly
```

Homebrew 7 and later refuses to load casks from a third-party tap until it is trusted (`brew trust`), and no longer taps one for you when you use the one-line form. On those versions the three steps above are needed. The cask downloads the release DMG and removes the quarantine attribute. Tapping it and the trust check were tested; a full install through Homebrew has not been tested.

## First run

On first launch Notchly plays a short hello animation and shows an onboarding window (`components/Onboarding/`): welcome, a feature picker, then permission steps for camera, calendar, reminders, accessibility and music, and a finish screen. Every step can be skipped and permissions can be granted later. To see onboarding again, see [setup.md](setup.md#resetting-first-run-onboarding).

## Updates

Notchly uses Sparkle. The feed URL is `https://cmxau.github.io/notchly/appcast.xml` (`SUFeedURL` in `Notchly/Info.plist`); updates are verified with the EdDSA public key in `SUPublicEDKey`. Check manually or toggle automatic checks and installs in Settings > About. The `updater/appcast.xml` in the repository is an empty template; the release workflows generate and merge the real appcast. See [security.md](security.md#network-use).

## Uninstall

1. Quit Notchly (right-click the notch menu or Activity Monitor; there is no menu bar icon).
2. Optional: in Settings > AI Integrations, disconnect each tool first so its hook entries are removed (see [ai-integrations.md](ai-integrations.md#disconnecting)). If you skip this, the hooks are harmless: they do nothing when the script or app is gone.
3. Delete `/Applications/Notchly.app`.
4. Optional cleanup of data:
   - Preferences: `defaults delete com.cmxau.notchly`
   - `~/.notchly/` (bridge file and hook script written by the agent integration)
   - Any backup files Notchly left next to agent settings (the Settings footer says a backup of the original is kept next to each edited file)
   - The app's sandbox container under `~/Library/Containers/com.cmxau.notchly/`
5. Remove Notchly from System Settings > Privacy & Security lists and Login Items if you enabled "Launch at login".

## Permissions

Declared in `Notchly/Info.plist` and `Notchly/Notchly.entitlements`. macOS asks only when a feature needs it.

| Permission | Why | Where it is requested |
| --- | --- | --- |
| Camera | Mirror (camera preview in the open notch) | Onboarding, or when you open the mirror; `managers/WebcamManager.swift` |
| Calendars | Show events | Onboarding, Calendar tab/settings; `Providers/CalendarServiceProviding.swift` uses `requestFullAccessToEvents` |
| Reminders | Show reminders | Same file, `requestFullAccessToReminders` |
| Accessibility (Device Control and Data Access on macOS 27) | Replace the system volume/brightness HUD and intercept media keys | Settings > HUDs; checked via the XPC helper. The Settings text uses the name for your macOS version ("Accessibility" or "Device Control and Data Access"). |
| Microphone | Teleprompter word tracking and voice-activated scroll. Info.plist: "Audio is not recorded." | First use of those modes; `private/Teleprompter.swift` |
| Speech Recognition | Teleprompter highlights the words you say | Same |
| System audio capture | Animate the equaliser from what is playing. Info.plist: "Nothing is recorded." | macOS prompts once; `managers/SystemAudioSpectrum.swift` |
| Automation (Apple Events) | Control Apple Music and Spotify; jump back to Terminal or iTerm2 from an agent request | Entitlement exceptions for `com.apple.Music`, `com.spotify.client`, `com.apple.Terminal`, `com.googlecode.iterm2` |
| Bluetooth | Detect accessories (e.g. AirPods) connecting | `com.apple.security.device.bluetooth` entitlement |
| Files (user selected, bookmarks) | Shelf items and settings import/export | Open/save panels, security-scoped bookmarks |
| Network client | Weather, update checks, YouTube Music local API, remote artwork | `com.apple.security.network.client` |
| Network server | The local agent bridge listens on the loopback interface | `com.apple.security.network.server`; see [ai-integrations.md](ai-integrations.md) |

Notes:

- The entitlements file also includes a mach-lookup exception for `$(PRODUCT_BUNDLE_IDENTIFIER)-spks` / `-spki`, which are Sparkle's installer and downloader services (`SUEnableDownloaderService`, `SUEnableInstallerLauncherService` are set in Info.plist).
- `Info.plist` sets `NSAllowsArbitraryLoads` (App Transport Security off). Not verified why; see [security.md](security.md).
- The agent integration edits files in your home folder through the unsandboxed XPC helper, which has its own allowlist rather than a macOS permission prompt. See [security.md](security.md#xpc-helper).
- Not verified from code: whether the app requests notification permission. Calendar alerts are drawn in the notch (`CalendarEventActivity`).

If you denied a permission, re-enable it in System Settings > Privacy & Security. See [troubleshooting.md](troubleshooting.md#permissions).
