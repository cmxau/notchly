# Contributing (developer notes)

The authoritative guide is the root [CONTRIBUTING.md](../CONTRIBUTING.md); this page does not replace it. Read it first. Setup steps are in [setup.md](setup.md).

## Process (summary of the root guide)

- Search existing issues; open one first for large changes.
- Code changes are based on the `dev` branch and PRs target `dev`. Documentation changes are based on `main`. The `Fork PR target policy` workflow (`.github/workflows/base_ref_check.yml`) checks fork PR targets; read it for the exact allowed paths.
- Branch names: lowercase letters, numbers and hyphens, e.g. `feature/add-dark-mode` or `fix/notification-crash`.
- PR description: clear title, what and why, `closes #123`, screenshots or a recording for UI changes. Keep translation changes in their own PR (`.github/PULL_REQUEST.md`).
- Report vulnerabilities privately, not in issues: [SECURITY.md](../SECURITY.md).

## Code style

The root guide has no formal style section (it is commented out). Follow the surrounding code: SwiftUI views with small helper functions, `@MainActor` managers exposed as `ObservableObject` singletons (`static let shared`), `Defaults` for persistence, `os.Logger` for logging (subsystem `com.cmxau.notchly`), and short file headers that say what the file is for. Remove debugging output before submitting.

## Where to add things

### A tab

1. Add a case to `NotchViews` in `Notchly/enums/generic.swift` (and its `title`/icon switch).
2. Draw its content: add the view where tabs are switched in `ContentView.NotchLayout()` and a button in `components/Tabs/` (see `TabSelectionView.swift`, `TabButton.swift`).
3. Add it to the defaults of `tabOrder` in `models/Constants.swift` if it should appear by default, and consider `OnboardingFeatures` (`private/`) if users should be able to opt in at first run.
4. Notchly-specific tabs live in `Notchly/private/` (see [architecture.md](architecture.md#the-private-convention)).

### A setting

Add the control to the right page in `components/Settings/SettingsView.swift` (pages are listed in [features.md](features.md)) using `Defaults.Toggle(key: ...)` or `@Default(...)`. A new page needs a sidebar `item(...)` entry and a `case` in the detail `switch` in the same file. Features in `private/` keep their settings in `private/ToolsSettings.swift` or their own view.

### A Defaults key

Declare `static let myKey = Key<Type>("myKey", default: ...)` in `extension Defaults.Keys`, in `models/Constants.swift` or next to the feature (as `private/Clipboard.swift` does). The type must be `Defaults.Serializable` (add conformance for new enums). Remember that settings export/import (`components/Settings/SettingsTransfer.swift`) copies every key except a small exclusion list; add secrets or machine-specific keys to `excludedKeys` there.

### An AI agent integration

1. Create a type conforming to `AgentIntegration` in `Notchly/agents/integrations/` (see `CursorIntegration.swift` for a small one, or reuse `ClaudeStyleIntegration.statusOnlyAgent` for tools with a Claude-style `settings.json`). It declares `kind`, `detectionPaths`, `configFiles`, `updatedConfigFiles(_:install:hookExecutable:)` (must only add or remove entries containing `AgentHookCommand.marker`) and `handle(_:hub:)`.
2. Add it to `AgentRegistry.integrations`.
3. Add its config files and folders to `NotchlyXPCHelper/AgentFileAllowlist.swift`. Without this the helper refuses to read or write them.
4. Add or update its entry in `AgentCatalog.entries` (set `integrationID` to the kind id) and an icon in `Notchly/agents/icons/`.
5. Update the supported-tools table in [ai-integrations.md](ai-integrations.md). Coordinate with the security policy before widening the allowlist.

### A localisation string

Strings live in `Notchly/Localizable.xcstrings` (edit it in Xcode's string catalog editor). Use string-literal `Text("...")`/`Label` so they are extracted. Per the root guide and PR template, keep translation edits in a separate pull request from code changes.

## Tests

There is no Swift test target in the repository (not verified beyond the project file). Python tests cover the CI scripts: see [setup.md](setup.md#workflow-tests).

## Licence

Notchly is GPL-3.0 ([LICENSE](../LICENSE)); contributions are under the same licence. Third-party notices: [THIRD_PARTY_LICENSES](../THIRD_PARTY_LICENSES).
