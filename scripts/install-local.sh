#!/bin/bash
# Builds Notchly (Release), installs it to /Applications and signs it with a fixed designated requirement.
#
# A plain ad-hoc signature is tied to the exact build, so macOS drops the Accessibility ("Device Control and
# Data Access" on macOS 27) permission after every rebuild. .github/scripts/sign_stable.sh signs with an
# identifier-only requirement, which keeps the grant valid across rebuilds.
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
DERIVED="${TMPDIR:-/tmp}/notchly-build"

xcodebuild -project Notchly.xcodeproj -scheme Notchly -configuration Release \
  -derivedDataPath "$DERIVED" build CODE_SIGNING_ALLOWED=NO | grep -E "error:|BUILD" || true

pkill -x Notchly 2>/dev/null || true
pkill -f NotchlyXPCHelper 2>/dev/null || true
rm -rf /Applications/Notchly.app
ditto "$DERIVED/Build/Products/Release/Notchly.app" /Applications/Notchly.app

APP=/Applications/Notchly.app
.github/scripts/sign_stable.sh "$APP"
open "$APP"
