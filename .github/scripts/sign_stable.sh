#!/bin/bash
# Re-signs an ad-hoc signed Notchly.app so that macOS keeps privacy grants (Accessibility, which macOS 27 calls
# "Device Control and Data Access") across updates.
#
# macOS records a grant against the app's designated requirement. For an ad-hoc signature that requirement is the
# exact build (its cdhash), so every new build looks like a different app and loses the grant. Here the app and its
# XPC helper get an identifier-only requirement instead, which every build satisfies.
#
# Trade-off: any ad-hoc signed program with the same identifier satisfies it too. A real certificate (Developer ID or
# Apple Development) already gives a stable requirement, so such builds are left alone.
#
# Usage: sign_stable.sh path/to/Notchly.app
set -euo pipefail

APP="${1:?usage: sign_stable.sh path/to/Notchly.app}"
HELPER="$APP/Contents/XPCServices/NotchlyXPCHelper.xpc"
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"

bundle_id() { /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$1/Contents/Info.plist"; }

# (captured first: with pipefail, grep -q closing the pipe early would make a match look like a failure)
DETAILS="$(codesign -dv "$APP" 2>&1 || true)"
if [[ "$DETAILS" != *"Signature=adhoc"* ]]; then
  echo "sign_stable: $APP is not ad-hoc signed, leaving its signature alone"
  exit 0
fi

# Keeps the sandbox and other entitlements the build was signed with
sign() { # path identifier
  codesign --force --sign - --preserve-metadata=entitlements,flags -i "$2" -r="designated => identifier \"$2\"" "$1"
}

sign "$HELPER" "$(bundle_id "$HELPER")"
sign "$APP" "$(bundle_id "$APP")"

# A build that wasn't signed at all (for example with CODE_SIGNING_ALLOWED=NO) leaves Sparkle's seal invalid
if ! codesign --verify --deep --strict "$APP" 2>/dev/null; then
  codesign --force --deep --sign - --preserve-metadata=entitlements,flags "$SPARKLE"
  sign "$HELPER" "$(bundle_id "$HELPER")"
  sign "$APP" "$(bundle_id "$APP")"
fi

codesign --verify --deep --strict "$APP"
echo "sign_stable: designated requirement is now:"
codesign -dr - "$APP" 2>&1 | grep designated
