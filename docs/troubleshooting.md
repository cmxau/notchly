# Troubleshooting

Related: [installation.md](installation.md), [features.md](features.md), [ai-integrations.md](ai-integrations.md), [setup.md](setup.md) (logging).

## The notch does not show

- Look at the top centre of the screen. There is no Dock window or menu bar icon; settings open from the gear in the open notch or by right-clicking the notch.
- First launch blocked by macOS ("unidentified developer", "damaged")? Release builds are not notarized. Run `xattr -dr com.apple.quarantine "/Applications/Notchly.app"` or right-click > Open ([installation.md](installation.md#gatekeeper--quarantine)).
- Multiple displays: check Settings > General > Show on all displays, Preferred display and "Automatically switch display". With the latter on and a different preferred display, the notch may be on another screen.
- Settings > Advanced > "Hide from screen recording" hides it from captures only; it should still be visible live.
- Notch hidden in full-screen apps or while playing media is a setting: see the hide option (`hideNotchOption`) and fullscreen media detection (`observers/FullscreenMediaDetection.swift`). The exact UI label was not verified.
- On a Mac without a notch the island floats with width and top gap from Settings > General.
- Relaunch from Applications. Quit via Activity Monitor if needed. Last resort: reset preferences (`defaults delete com.cmxau.notchly`, see [setup.md](setup.md#resetting-first-run-onboarding)).

## The notch does not open on hover

Check Settings > General: "Open notch on hover" and the minimum hover duration; "Extend hover area" under Advanced. A non-activating panel can be blocked by apps using a higher window level.

## Permissions

- Denied or missed a prompt: System Settings > Privacy & Security, then Camera, Calendars, Reminders, Accessibility (called Device Control and Data Access on macOS 27), Microphone, Speech Recognition, Automation, or the audio capture entry.
- HUD replacement does nothing: it needs Accessibility (Device Control and Data Access on macOS 27). The permission is checked via the XPC helper, so the entry may appear under the helper rather than the app. Toggle it off and on after granting.
- Calendar empty: Notchly needs full access to events and reminders (macOS 14+ API). Also check the calendars selected in Settings > Calendar.
- Teleprompter: word tracking and voice modes need Microphone and Speech Recognition; classic mode needs neither.
- Equaliser only animates: system audio capture was not allowed, or macOS is older than 14.2. It falls back to the animation.
- Music controls do nothing for Apple Music or Spotify: allow Notchly under Automation.

## Music

- Wrong or no player: choose the Music source in Settings > Music. Defaults depend on the macOS version.
- YouTube Music needs the pear-desktop app with its API server enabled at `http://localhost:26538` (linked in Settings > Music). Authentication goes through that app.

## Agent hooks not reporting

1. Settings > AI Integrations: is the tool listed as connected? "Not found" means its folder (for example `~/.claude`) does not exist. "Failed" shows why (often an unparsable settings file, which Notchly leaves untouched).
2. Check `~/.notchly/bridge` and `~/.notchly/bin/notchly-agent-hook` exist. Notchly rewrites them at launch. Start Notchly, then start a new agent session (some tools read hooks only at start).
3. Test by hand: `~/.notchly/bin/notchly-agent-hook claude Notification < /dev/null`. No output and exit 0 is normal when Notchly is not running.
4. Only Claude Code and Antigravity support approvals in the notch; other tools show status only.
5. A request you did not answer returns to the terminal prompt after the timeout (default 5 minutes).
6. You disconnected a tool earlier: it will not reconnect by itself. Press Connect.
7. Config conflicts: OpenCode's `notchly.js` is not overwritten if Notchly did not write it.
8. Watch logs: `log stream --predicate 'subsystem == "com.cmxau.notchly" && category == "AgentBridge"'`.
9. Jump-to-terminal not working: only partly implemented (Terminal.app, iTerm2 and bundle-id mapped terminals); tmux/kitty/WezTerm pane focusing and SSH remote agents are not implemented in the current source.

## Call indicator caveats

"Show FaceTime and phone calls in the notch" (Settings > Advanced) has no public call API behind it. `CallMonitor` decides you are on a call when FaceTime is running and the default input device is in use, polled every 2 seconds. Consequences: calls in other apps (Zoom, Teams, WhatsApp) are not detected, and a FaceTime window that is open while another app uses the microphone can show a false positive.

## Weather shows nothing or the wrong city

- Set the city in Settings > Tools and press Return. The city text is geocoded by Open-Meteo; if the place is wrong, try a different spelling or a larger nearby city (how ambiguous names are resolved was not verified).
- Needs internet access; a message appears if the lookup fails. Units: Fahrenheit toggle.

## Clipboard history

- Empty: check "Keep clipboard history" in Settings > Tools. Only text is kept, and items flagged by password managers are skipped.
- Cmd-Shift-C does nothing: shortcuts may be disabled in Settings > Shortcuts, or conflict with another app's shortcut.

## Shelf

Drag detection opens the notch when you drag near it; "Expanded drag detection area" widens it. Items are removed after dragging only if that option is on.

## Updates

Settings > About > Check for Updates. Sparkle needs network access to `cmxau.github.io`. If you built the app yourself with a different bundle id or key, updates from the official feed will not apply.

## Still stuck

Open an issue using the templates in `.github/ISSUE_TEMPLATE` and include macOS and app version (Settings > About), steps to reproduce, and relevant log lines. Security problems go through [SECURITY.md](../SECURITY.md), not issues.
