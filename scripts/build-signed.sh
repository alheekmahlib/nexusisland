#!/usr/bin/env bash
#
# build-signed.sh — build NexusIsland with real Developer ID code signing.
#
# Usage: scripts/build-signed.sh
#
# Builds the app without signing (to avoid SPM dependency conflicts), then
# signs the .app bundle with your Developer ID Application certificate +
# entitlements. This is required for TCC permission prompts (Reminders,
# Location, Calendar) to appear — ad-hoc signed apps can't request them.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Detect the Developer ID Application identity from the keychain.
SIGN_IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null \
  | grep "Developer ID Application" | head -1 \
  | sed 's/.*"\(.*\)".*/\1/')

if [ -z "$SIGN_IDENTITY" ]; then
  echo "Error: no 'Developer ID Application' certificate found in Keychain." >&2
  echo "       Run this script on a Mac that has a Developer ID cert installed." >&2
  exit 1
fi

echo "Signing identity: $SIGN_IDENTITY"

# 1. Generate project.
xcodegen generate

# 2. Build without signing (avoids SPM auto-signing conflicts).
echo "Building (unsigned)…"
xcodebuild \
  -project NexusIsland.xcodeproj \
  -scheme NexusIsland \
  -configuration Debug \
  -destination 'platform=macOS' \
  -clonedSourcePackagesDirPath .build/packages \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build 2>&1 | tail -5

APP_PATH="build/DerivedData/Build/Products/Debug/NexusIsland.app"

# 3. Sign with Developer ID + entitlements.
echo "Signing with Developer ID + entitlements…"
codesign --force --deep --sign "$SIGN_IDENTITY" \
  --entitlements NexusIsland/NexusIsland.entitlements \
  "$APP_PATH"

# 4. Verify.
echo "Verifying signature…"
codesign -dv "$APP_PATH" 2>&1 | grep -E "Identifier|TeamIdentifier"

echo ""
echo "✅ Built and signed: $APP_PATH"
echo "   Run: open \"$APP_PATH\""
