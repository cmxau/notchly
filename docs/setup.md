# Developer setup

See also [architecture.md](architecture.md) and [contributing.md](contributing.md).

## Requirements

- A Mac with a recent Xcode. The task brief calls for macOS 15.6+ and Xcode 26+; the project itself sets `MACOSX_DEPLOYMENT_TARGET = 14.0` and `SWIFT_VERSION = 5.0`. CI uses `macos-latest` runners in `build_reusable.yml` and an `^16` Xcode in the legacy `cicd.yml`. Use a current Xcode; the minimum that works was not verified.
- Python 3 for the workflow tests and DMG packaging (optional).

## Clone and open

```bash
git clone https://github.com/cmxau/notchly.git
cd notchly
open Notchly.xcodeproj
```

Note the branch policy in [contributing.md](contributing.md): code contributions target `dev`.

## Dependencies

Swift packages resolve automatically when Xcode opens the project (pinned in `Notchly.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`). From the command line:

```bash
xcodebuild -resolvePackageDependencies -project Notchly.xcodeproj
```

The `mediaremote-adapter/` folder (framework and Perl script for system Now Playing) is in the repository; it is not a package.

## Build and run

1. Select the `Notchly` scheme and "My Mac".
2. Press Run (Cmd-R). The app has no Dock-icon window or menu bar item; look for the notch at the top of the screen.
3. Command-line build (as CI does in `build_reusable.yml`, which uses `xcodebuild clean archive`):

```bash
xcodebuild build -project Notchly.xcodeproj -scheme Notchly -configuration Debug
```

The `NotchlyXPCHelper` target is built as part of the app. Features using the helper (accessibility checks, brightness, agent config files) do not work if it is missing from the built product.

## Signing

- `CODE_SIGN_STYLE = Automatic` and `DEVELOPMENT_TEAM` is empty in the project: choose your own team under Signing & Capabilities for both the app and `NotchlyXPCHelper`, or the build will not run on your Mac.
- The bundled `MediaRemoteAdapter.framework` keeps the upstream signature, so the alpha workflow builds with the hardened runtime off (see comments in `.github/workflows/alpha_release.yml`).
- Release and nightly workflows sign with certificates from repository secrets (`BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`, `KEYCHAIN_PASSWORD`) and Sparkle appcast keys; forks can use the alpha workflow, which needs no signing secrets and produces an ad-hoc signed, non-notarized build.
- The entitlements reference `$(PRODUCT_BUNDLE_IDENTIFIER)` for the Sparkle mach-lookup names, so they follow the bundle id if you change it. Verify Sparkle updates if you fork under a different id.

## Workflow tests

The CI helper scripts have `unittest` tests in `.github/scripts/tests/`. They import the scripts via `sys.path`, so run from the repository root:

```bash
python3 -m unittest discover -s .github/scripts/tests -v
```

At the time of writing this runs 39 tests and passes.

`test_workflow_smoke.py` reads the YAML in `.github/workflows` as text and checks structural invariants (for example the nightly tag and build-number scheme), so edits to workflows can fail it.

## Building a DMG locally

`Configuration/dmg/create_dmg.sh <app_path> <dmg_output> <volume_name>` wraps `dmgbuild` with `dmgbuild_settings.py`. Install the pinned requirements first:

```bash
python3 -m pip install --require-hashes -r Configuration/dmg/requirements.txt
```

## Resetting first-run onboarding

Preferences live in the `com.cmxau.notchly` domain. Quit Notchly, then:

```bash
defaults delete com.cmxau.notchly
```

This clears every setting, including clipboard history and the agent bridge token (a new one is generated on next launch and the hook files are rewritten). `firstLaunch` (an `@AppStorage` flag in `NotchlyViewCoordinator`) then defaults to true again, so onboarding runs. To reset only onboarding: `defaults delete com.cmxau.notchly firstLaunch`. If you run a sandboxed build, the plist is in the app container, and `defaults` addresses it by bundle id.

## Debugging tips

- Logging uses `os.Logger` with subsystem `com.cmxau.notchly` (categories such as `AgentBridge`, `AgentIntegration`, `TerminalJumper`). Stream them:

```bash
log stream --predicate 'subsystem == "com.cmxau.notchly"' --level debug
```

- Agent bridge: check `~/.notchly/bridge` (port and token) and test the script by hand: `~/.notchly/bin/notchly-agent-hook claude Notification < /dev/null`. It prints nothing and exits 0 if Notchly is not running.
- `components/TestView.swift` and `Preview Content/` support SwiftUI previews.
- The notch window is a non-activating panel; use Debug > View Debugging in Xcode or the Accessibility Inspector to inspect it.
- Multi-display issues: toggle "Show on all displays" in Settings > General; windows are rebuilt on `NSApplication.didChangeScreenParametersNotification`.
- The XPC helper runs as a separate process; attach to it from Xcode (Debug > Attach to Process) to debug helper calls.
