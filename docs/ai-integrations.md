# AI integrations

Notchly can show what AI coding tools are doing in the notch, and for some tools let you approve or deny requests there. Source: `Notchly/agents/`, `Notchly/components/Agents/`, `Notchly/components/Settings/Agents/`, `NotchlyXPCHelper/AgentFile*.swift`. The feature is marked Beta in Settings and is under active security hardening; see [SECURITY.md](../SECURITY.md) and [security.md](security.md) for the current policy.

## How it works

1. **Hook script.** `Notchly/agents/notchly-agent-hook.sh` is bundled with the app. Notchly copies it to `~/.notchly/bin/notchly-agent-hook` and keeps it up to date (edits are overwritten). Agents run it from their hook settings as `notchly-agent-hook <agent> <event>`, with the hook payload on stdin.
2. **Bridge file.** Notchly writes `~/.notchly/bridge` containing `port=` and `token=` lines (and `host=` for remote agents). The script reads it to find the app.
3. **Local server.** `AgentBridgeServer` listens with `Network.framework` restricted to the loopback interface, on a system-assigned port. The script sends `POST /v1/hooks/<agent>` with headers including `X-Notchly-Token`, `X-Agent-Event` and terminal-location headers.
4. **Checks on each request** (`AgentBridgeServer.parse`): POST only, no `Origin` header (blocks browsers), `Host` must be `127.0.0.1:<port>` or `localhost:<port>` (blocks DNS rebinding), the token must match, path must start with `/v1/hooks/`, body at most 4 MB. Otherwise the server answers 400/403/404/413.
5. **Hub and UI.** `AgentHub` turns events into sessions (status in the closed notch and the Agents tab) and, for tools that support it, pending permission requests, questions and plans. You answer in the notch (or with the shortcuts below); the answer goes back as the script's output. If nobody answers within the configured timeout, the request is handed back to the agent's own terminal prompt.
6. **Failure behaviour.** If Notchly is not running or does not answer, the script prints nothing and exits 0, so the agent behaves as if the hook were not installed. Status-only hooks wait about 3 seconds at most; hooks that wait for a decision (`NOTCHLY_WAIT=always` or `tools:...`) wait up to 86400 seconds, or until the connection closes.

The token is a random string generated on first run and stored in Defaults (`agentBridgeToken`). It is not exported by Settings > Advanced > Export Settings.

## Installers

`AgentIntegrationInstaller` connects every detected, not-user-disconnected tool at launch, and when you press Connect. For each tool it reads the config files, calls the integration's `updatedConfigFiles(...)`, and writes back only changed files. Integrations are designed to add or remove only entries containing the marker `notchly-agent-hook` and to leave your own hooks alone; the Settings footer says a backup of the original is kept next to the file. If a settings file cannot be parsed, it is left untouched and the row shows an error. File access goes through the unsandboxed XPC helper, restricted by `AgentFileAllowlist` to the paths below.

## Supported tools

Tools with an integration (`AgentRegistry`, `AgentCatalog`). "Capabilities" are from each `AgentKind`.

| Tool | Id | Config file edited | Capabilities |
| --- | --- | --- | --- |
| Claude Code | `claude` | `~/.claude/settings.json` | status, approvals, questions, plans |
| Codex CLI | `codex` | `~/.codex/config.toml` (notify program) | status |
| Gemini CLI | `gemini` | `~/.gemini/settings.json` | status |
| Antigravity | `antigravity` | `~/.gemini/config/hooks.json` | status, approvals (`run_command`) |
| CodeBuddy | `codebuddy` | `~/.codebuddy/settings.json` | status |
| Copilot CLI | `copilot` | `~/.copilot/hooks/notchly.json` | status |
| Cursor (editor and Cursor Agent) | `cursor` | `~/.cursor/hooks.json` | status |
| Droid | `droid` | `~/.factory/settings.json` | status |
| OpenCode | `opencode` | `~/.config/opencode/plugin/notchly.js` | status |
| Qoder | `qoder` | `~/.qoder/settings.json` | status |
| Qoder CN | `qoder-cn` | `~/.qoder-cn/settings.json` | status |
| Qwen Code | `qwen` | `~/.qwen/settings.json` | status |

Plus `~/.notchly/bridge` and `~/.notchly/bin/notchly-agent-hook` for the bridge itself.

Listed in Settings as "not supported yet" (no integration): Amp, DeepSeek, Devin, Grok CLI, Hermes, Kimi CLI, Kimi Code, MiMo Code, Mistral Vibe, Oh My Pi, OpenClaw, Pi, dsh, ZCode; desktop apps Claude, Codex, Gemini, Grok, Kimi, Qoder Work, Qwen Work, WorkBuddy, Z.ai; and IDEs Kiro, Trae, VS Code.

A tool counts as installed if its detection folder exists (for example `~/.claude`). The OpenCode integration refuses to overwrite a `notchly.js` that Notchly did not write.

## Using it

- Settings > AI Integrations: per-tool Connect / Disconnect with status (not found, not connected, connected, failed), "Open the notch when an agent needs you", "Show agent activity in the closed notch", timeout (1 min, 5 min, 15 min, never), sounds.
- Shortcuts while an agent is waiting: Ctrl-Y approve, Ctrl-N deny, Ctrl-T jump to terminal (configurable in Settings > Shortcuts).
- Jump to terminal (`TerminalJumper`) uses the terminal location the script reports. Terminal.app and iTerm2 have Apple Events exceptions; Warp and others are mapped by bundle id. Exact behaviour per terminal was not verified.

## Not implemented in the current source

The following have protocol methods or stubs but reply "Not implemented yet", and their settings sections are empty views: remote agents over SSH tunnels (`SSHTunnels.swift`, `AgentRemoteSettings.swift`), terminal pane focusing for tmux/kitty/WezTerm (`TerminalPanes.swift`), and Claude usage/quota (`AgentUsage.swift`). The hook script and server already understand the `host=` bridge line and related headers.

## Privacy

- Everything stays on the Mac: the server only binds loopback, and the script only talks to `127.0.0.1`/`localhost`. The app does not send agent events anywhere else (verified for `agents/`; not a guarantee about the agents themselves).
- Event payloads can contain prompts, file paths, commands and tool input. Permission prompts show the full command, path or URL. They are held in memory by `AgentHub`; whether anything is persisted was not verified.
- Anything with filesystem access as you can read `~/.notchly/bridge` and obtain the token. This is by design: the token stops other local software that cannot read your home folder and web pages, not same-user processes.

## Disconnecting

- One tool: Settings > AI Integrations > Disconnect. Notchly removes its entries from that tool's config and remembers your choice (`agentIntegrationsDisconnected`) so it does not reconnect automatically.
- All tools: disconnect each, or turn the feature off (`agentIntegrationEnabled`; onboarding's "AI agents" choice sets it). Not verified: which exact components stop when it is off.
- Full removal: disconnect tools, quit Notchly, delete `~/.notchly/`. Any stray `notchly-agent-hook` entry left in an agent's settings is a no-op once the script is gone (the command is `test -x script && ...; exit 0`).

Troubleshooting: [troubleshooting.md](troubleshooting.md#agent-hooks-not-reporting). Adding a tool: [contributing.md](contributing.md#an-ai-agent-integration).
