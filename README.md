# Notchly

Notchly turns the notch (or a floating pill) on your Mac into a small control centre for music, calendar, files, clipboard and your AI coding agents.

## Features

### Notch core

- Two shapes: **Notch** or **Island**, with sizing options for displays that have no physical notch
- Tabbed panel that opens from the notch: Home, Music, Calendar, Shelf, AI agents, Teleprompter, Clipboard, Timer and Weather. Tabs can be hidden and reordered
- Live activities and toasts for calls, Caps Lock and network changes
- Replacements for the system volume and brightness HUDs
- Battery and charging indicator, and an optional notch pet
- Mirror: a camera preview in the notch

### Media

- Now playing with playback controls, album art and a spectrum visualiser
- Configurable music controller; lyrics are looked up from LRCLIB
- Calendar events and reminders

### Productivity tools

- Teleprompter with word tracking, classic scroll and voice-activated scroll
- Focus and break timer
- Weather for a city you choose, now and the next hours

### Files and clipboard

- Shelf: drop files into the notch, then share or AirDrop them. A floating shelf is also available
- Clipboard history with search and favourites

### AI agents

- See what your AI coding agents are doing and answer their requests from the notch
- One-click connection for Claude Code, Codex CLI, Gemini CLI, Cursor, Copilot CLI, Droid, CodeBuddy, Qwen Code, OpenCode, Qoder, Qoder CN and Antigravity
- Many more tools are listed in Settings as not supported yet
- Agents on remote servers over SSH, terminal jump, usage view and sounds

Details: [docs/ai-integrations.md](docs/ai-integrations.md).

### Customisation

- Settings sections: General, Tabs, Media, Calendar, HUD, Shelf, Tools, Teleprompter, Agents, Shortcuts, Extensions, Advanced, About
- Choice of app icon
- Global keyboard shortcuts
- Settings backup and restore

## Requirements

- macOS 14 (Sonoma) or later. This is the deployment target in the Xcode project and the Homebrew cask.
- Apple Silicon and Intel support is not stated in the project settings, so it is not claimed here.

## Install

### Release DMG

Download the latest `.dmg` from [Releases](https://github.com/cmxau/notchly/releases/latest) and move Notchly to Applications.

Notchly is not notarized yet, so macOS warns about an unidentified developer on first launch. Run this once after moving it to Applications:

```bash
xattr -dr com.apple.quarantine "/Applications/Notchly.app"
```

### Homebrew

The release workflow publishes a cask to the `cmxau/homebrew-notchly` tap on each release:

```bash
brew install --cask cmxau/notchly/notchly
```

The cask removes the quarantine attribute after install. A release-candidate cask, `notchly@rc`, is published too.

More detail: [docs/installation.md](docs/installation.md).

## First launch

On first launch Notchly shows an onboarding flow: a welcome, a music controller choice, a **feature picker** ("What would you like in your notch?") and a permissions step. The picker offers Music, Calendar, Shelf, AI agents, Clipboard, Timer, Weather, Teleprompter, Notch pet and Live alerts. Anything you deselect is turned off. You can change all of it later in Settings.

See [docs/setup.md](docs/setup.md).

## Permissions

Each permission is requested only when the related feature needs it.

| Permission | Why |
| --- | --- |
| Calendar and Reminders | Show events and reminders in the Calendar tab |
| Camera | Live preview for Mirror |
| Microphone | Teleprompter follows your voice. Audio is not recorded |
| Speech recognition | Teleprompter highlights the words you say |
| System audio capture | Animate the spectrum from what is playing. Nothing is recorded |
| Bluetooth | Show which accessory just connected, such as AirPods |
| Automation (Apple Events) | Control Spotify and Apple Music, and open Terminal and iTerm2 for agent jump |
| Accessibility (called Device Control and Data Access on macOS 27) | Checked and requested by the helper process; see [docs/security.md](docs/security.md) |
| Network (client) | Weather, lyrics, update checks and SSH tunnels; see Privacy |
| Network (server) | Local-only listener for AI agent hooks |
| User-selected files | Files you drop on the Shelf or choose in a file picker |

Notchly is sandboxed. Access to agent configuration files in your home folder goes through a separate helper (NotchlyXPCHelper). See [docs/security.md](docs/security.md).

## Build from source

Requires macOS 14 or later and a recent Xcode.

```bash
git clone https://github.com/cmxau/notchly.git
cd notchly
open Notchly.xcodeproj
```

Press `Cmd + R` to build and run. See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## Documentation

- [docs/README.md](docs/README.md): index
- [docs/architecture.md](docs/architecture.md): how the app is put together
- [docs/installation.md](docs/installation.md): install and update
- [docs/setup.md](docs/setup.md): first launch and configuration
- [docs/contributing.md](docs/contributing.md): development guide
- [docs/features.md](docs/features.md): feature reference
- [docs/ai-integrations.md](docs/ai-integrations.md): connecting AI agents
- [docs/security.md](docs/security.md): sandbox, entitlements and helper
- [docs/troubleshooting.md](docs/troubleshooting.md): common problems

## Privacy

- There is no analytics or telemetry in the app.
- Your data (shelf, clipboard history, settings) is stored on your Mac.
- Network calls the code makes:
  - Weather: city name and coordinates go to Open-Meteo (`geocoding-api.open-meteo.com`, `api.open-meteo.com`), only when a city is set.
  - Lyrics: track title and artist go to LRCLIB (`lrclib.net`).
  - Updates: Sparkle checks `https://cmxau.github.io/notchly/appcast.xml`; "What's new" reads GitHub releases (`api.github.com/repos/cmxau/notchly/releases`).
  - AI agents: hook events arrive on a local server bound to the loopback interface; they do not leave your Mac.
  - SSH tunnels to servers you configure for remote agents.

## Contributing and security

- Contributions: [CONTRIBUTING.md](CONTRIBUTING.md)
- Report vulnerabilities privately: [SECURITY.md](SECURITY.md)

## License and attribution

Notchly is licensed under GPL-3.0, see [LICENSE](LICENSE). It is built on the open-source [Boring Notch](https://github.com/TheBoredTeam/boring.notch) project and keeps its license and third-party notices; see [THIRD_PARTY_LICENSES](THIRD_PARTY_LICENSES).
