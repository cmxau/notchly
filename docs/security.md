# Security and privacy

This page describes what the code is designed to do, as read from the repository. Security hardening of the agent bridge and the XPC helper is ongoing: the authoritative, current policy is [SECURITY.md](../SECURITY.md). If this page and the code disagree, the code and SECURITY.md win.

## Reporting a vulnerability

Do not open a public issue. Use GitHub's private advisory form: <https://github.com/cmxau/notchly/security/advisories/new> (also in [SECURITY.md](../SECURITY.md)). Report problems in third-party dependencies to their maintainers.

## Summary

- The main app is sandboxed (`Notchly.entitlements`: `com.apple.security.app-sandbox` true).
- A separate, **unsandboxed** XPC helper does the few things the sandbox forbids.
- The only listening socket is the agent bridge, bound to the loopback interface and protected by a token.
- There is no analytics or telemetry code that was found in `Notchly/`. Not verified: behaviour of bundled third-party code beyond Sparkle's defaults.

## Data stored locally

| Data | Where | Notes |
| --- | --- | --- |
| Settings | UserDefaults domain `com.cmxau.notchly` (via the Defaults package) | Includes layout, toggles, weather city, chosen music source. |
| Clipboard history | Same domain, key `clipboardHistory` | See below. Plain, unencrypted preference data. |
| Agent bridge token | Defaults key `agentBridgeToken`, and `~/.notchly/bridge` | Random string; see [ai-integrations.md](ai-integrations.md). |
| Shelf items | `~/Library/Application Support/Notchly/Shelf` inside the sandbox container (per `ShelfPersistenceService`), plus security-scoped bookmarks | Files you drop on the shelf. |
| Agent config edits | `~/.claude`, `~/.codex`, etc. | Only the paths in the helper allowlist. |
| Hook script and bridge | `~/.notchly/bin/notchly-agent-hook`, `~/.notchly/bridge` | |

### Clipboard history

- Opt-out: `clipboardHistoryEnabled` (default on) in Settings > Tools.
- Text only. Polls the pasteboard change count about every 0.7 s; keeps at most 60 items (`ClipboardManager.limit`).
- Skips items flagged `org.nspasteboard.ConcealedType` or `TransientType`, which password managers set. Apps that do not set these flags are not filtered.
- "Clear history (keeps favourites)" removes unfavourited items; favourites remain until removed.
- Because history lives in preferences, anything copied while it is on (including secrets from apps that do not mark them) is stored on disk in clear text. Turn it off if that matters.
- Settings export (`SettingsTransfer`) copies the defaults domain except `agentBridgeToken`, `agentIntegrationsDisconnected`, `clipboardHistory` and keys beginning `NS`, `Apple`, `SU`, `com.apple.`, so an exported file does not contain clipboard text or the bridge token. Imported files are written back into the defaults domain.

## Entitlements

From `Notchly/Notchly.entitlements`: app sandbox; Apple events automation with exceptions for Spotify, Apple Music, Terminal and iTerm2; audio input; Bluetooth; camera; calendars; app- and document-scope bookmarks; user-selected read/write files; network client; network server; mach-lookup exceptions for Sparkle's installer and downloader services. Reasons for each are in [installation.md](installation.md#permissions).

`Info.plist` sets `NSAppTransportSecurity > NSAllowsArbitraryLoads = true`, which allows plain HTTP. One known use is the YouTube Music controller's `http://localhost:26538` (see below). Not verified whether other uses require it or whether it could be narrowed.

## XPC helper

`NotchlyXPCHelper` (`com.cmxau.notchly.NotchlyXPCHelper`) runs outside the sandbox so it can reach the real home folder, accessibility APIs and private brightness frameworks. The app connects with `NSXPCConnection(serviceName:)`. It exposes:

- Accessibility trust checks and prompt.
- Screen and keyboard brightness (uses private CoreBrightness APIs).
- Agent file checks, reads and writes. `AgentFileAllowlist` limits these to a fixed list of relative paths (the agents' settings files, `~/.notchly/bridge`, the hook script). Paths must be relative with no `.` or `..` components. Read-only and listable folders are currently empty sets.
- Stubs (reply "Not implemented yet") for SSH tunnels, remote file access, terminal panes and Claude usage.

Design intent: an unsandboxed helper that edits files on request is sensitive, so its surface is kept to an allowlist. The helper only accepts a connection from the executable of the app bundle that contains it (checked by the caller's process path in `NotchlyXPCHelper/main.swift`). It is not a code-signing requirement, because releases are ad-hoc signed and there is no team ID to require; tighten it once builds are signed with a Developer ID. Not runtime-tested beyond the helper starting with the app.

## Agent bridge

Loopback-only HTTP listener (`requiredInterfaceType = .loopback`), random token required in `X-Notchly-Token`, `Origin` header rejected, `Host` must be localhost or 127.0.0.1, 4 MB request cap, POST only. The token is stored in preferences and in `~/.notchly/bridge` in plain text. Processes running as you can read it. Details: [ai-integrations.md](ai-integrations.md).

## Network use

What leaves the Mac (found by searching the source for URLs):

| Feature | Destination | What is sent |
| --- | --- | --- |
| Weather | `geocoding-api.open-meteo.com`, `api.open-meteo.com` | The city name you typed, then the resulting coordinates. Only when a city is set. |
| Updates | `https://cmxau.github.io/notchly/appcast.xml` via Sparkle; downloads from GitHub releases | Sparkle's standard update request. `SUEnableSystemProfiling` is not set in `Info.plist` (so Sparkle's default applies; not verified). Updates are signed (EdDSA key `SUPublicEDKey`). |
| Release notes in About | `api.github.com/repos/cmxau/notchly/releases` | A GitHub API request. |
| Synced lyrics | `lrclib.net` | Track title and artist of what is playing, when lyrics are fetched (`MusicManager`). |
| Album art and other remote images | URLs supplied by the player | Not enumerated. |
| YouTube Music | `http://localhost:26538` | Local only; talks to the pear-desktop app's API on your Mac. |
| Agent bridge | loopback | Local only. |

Everything else (calendar, clipboard, microphone audio, camera frames, system audio levels) is processed on the Mac. Teleprompter audio and the equaliser tap are not recorded per their Info.plist usage strings; the speech recognition path may be handled by Apple's speech service depending on system settings (not verified).

## Updates and builds

Release, nightly and alpha builds come from GitHub Actions (`.github/workflows`). Stable and nightly builds are signed with repository secrets and publish a Sparkle appcast; alpha builds are ad-hoc signed and not notarized. The README states releases are not notarized yet. CodeQL runs on pushes and PRs to `main` and `dev` and weekly. The bundled `MediaRemoteAdapter.framework` keeps its upstream signature.

## Practical advice

- Turn off clipboard history if you copy secrets.
- Review the permissions you grant ([installation.md](installation.md#permissions)).
- Disconnect agent integrations you do not use ([ai-integrations.md](ai-integrations.md#disconnecting)).
- Download builds only from the repository's Releases page.
