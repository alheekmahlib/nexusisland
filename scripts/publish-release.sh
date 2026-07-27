#!/bin/bash
# Publish a signed, notarized NexusIsland release to Cloudflare R2.
#
# Usage:
#   ./scripts/publish-release.sh <version> [release-note-1] [release-note-2] ...
#
# Example:
#   ./scripts/publish-release.sh 1.2.0 "New Focus module" "Fixed Weather crash"
#
# Prerequisites (see cloudflare/README.md):
#   • .env contains APPLE_ID / APP_SPECIFIC_PASSWORD / TEAM_ID / SIGNING_IDENTITY
#     (for codesign + notarize) AND R2_ACCESS_KEY_ID / R2_SECRET_ACCESS_KEY /
#     R2_ENDPOINT / R2_BUCKET / R2_PUBLIC_BASE_URL (for the upload).
#   • aws CLI installed (`brew install awscli`) — used for the S3-compatible
#     R2 upload. The `--endpoint-url` flag points it at R2.
#
# This script:
#   1. Bumps MARKETING_VERSION in project.yml to <version>.
#   2. Builds + signs + notarizes the DMG (reuses build-and-release.sh).
#   3. Uploads the DMG and a freshly-generated manifest.json to R2.
#   4. Prints the public URLs.

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <version> [release-note]..."
  echo "Example: $0 1.2.0 \"New Focus module\" \"Fixed Weather crash\""
  exit 1
fi

VERSION="$1"
shift
RELEASE_NOTES=("$@")

# Load credentials (Apple + R2). .env is gitignored.
source .env 2>/dev/null || { echo "ERROR: .env not found. See cloudflare/README.md."; exit 1; }

for var in APPLE_ID APP_SPECIFIC_PASSWORD TEAM_ID SIGNING_IDENTITY \
          R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_ENDPOINT R2_BUCKET R2_PUBLIC_BASE_URL; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: $var is not set in .env"
    exit 1
  fi
done

if ! command -v aws >/dev/null 2>&1; then
  echo "ERROR: aws CLI not installed. Install with: brew install awscli"
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Step 1/4: bump version to $VERSION in project.yml"
# project.yml uses MARKETING_VERSION: "x.y.z" — replace it in place.
sed -i.bak -E "s/MARKETING_VERSION: \".*\"/MARKETING_VERSION: \"$VERSION\"/" project.yml
# Also auto-increment CURRENT_PROJECT_VERSION (the integer build number) so
# each release has a unique build, not a constant "1". Read the current
# value, +1, and write it back. macOS uses this for "build still increases"
# checks during notarization and for App Store / Sparkle-style update logic.
CURRENT_BUILD=$(grep -E 'CURRENT_PROJECT_VERSION: "[0-9]+"' project.yml | grep -oE '[0-9]+' || echo "0")
NEW_BUILD=$((CURRENT_BUILD + 1))
sed -i.bak2 -E "s/CURRENT_PROJECT_VERSION: \"[0-9]+\"/CURRENT_PROJECT_VERSION: \"$NEW_BUILD\"/" project.yml
rm -f project.yml.bak project.yml.bak2
echo "    Bumped MARKETING_VERSION to $VERSION, CURRENT_PROJECT_VERSION to $NEW_BUILD."
echo "    Remember to commit + push this change."

echo "==> Step 2/4: build + sign + notarize (this takes 5-15 minutes)"
sh scripts/build-and-release.sh
DMG_PATH="build/NexusIsland.dmg"
if [ ! -f "$DMG_PATH" ]; then
  echo "ERROR: $DMG_PATH not found after build."
  exit 1
fi

DMG_FILENAME="NexusIsland-${VERSION}.dmg"
DMG_KEY="${DMG_FILENAME}"
MANIFEST_KEY="manifest.json"

echo "==> Step 3/4: upload DMG + manifest to R2"
export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"

echo "   Uploading $DMG_KEY ($(du -h "$DMG_PATH" | cut -f1))..."
aws s3 cp "$DMG_PATH" "s3://$R2_BUCKET/$DMG_KEY" \
  --endpoint-url "$R2_ENDPOINT" \
  --content-type "application/octet-stream" \
  --cache-control "public, max-age=31536000, immutable" \
  >/dev/null

# Build the manifest JSON. The `releaseNotes` array is quoted safely via jq.
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not installed. Install with: brew install jq"
  exit 1
fi

DOWNLOAD_URL="$R2_PUBLIC_BASE_URL/$DMG_KEY"
PUBLISHED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

NOTES_JSON=$(printf '%s\n' "${RELEASE_NOTES[@]}" | jq -R . | jq -s .)

MANIFEST=$(jq -n \
  --arg version "$VERSION" \
  --arg downloadURL "$DOWNLOAD_URL" \
  --argjson releaseNotes "$NOTES_JSON" \
  --arg minimumOSVersion "14.0" \
  --arg publishedAt "$PUBLISHED_AT" \
  '{version:$version, downloadURL:$downloadURL, releaseNotes:$releaseNotes, minimumOSVersion:$minimumOSVersion, publishedAt:$publishedAt}')

echo "$MANIFEST" > build/manifest.json

echo "   Uploading $MANIFEST_KEY..."
# manifest must NOT be cached aggressively — we want new versions visible fast.
aws s3 cp build/manifest.json "s3://$R2_BUCKET/$MANIFEST_KEY" \
  --endpoint-url "$R2_ENDPOINT" \
  --content-type "application/json" \
  --cache-control "public, max-age=300" \
  >/dev/null

echo "==> Step 4/4: verify"
MANIFEST_URL="$R2_PUBLIC_BASE_URL/$MANIFEST_KEY"
echo "   Manifest:  $MANIFEST_URL"
echo "   DMG:       $DOWNLOAD_URL"
echo ""
echo "Verifying manifest is publicly readable..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$MANIFEST_URL")
if [ "$HTTP_CODE" = "200" ]; then
  echo "✅ manifest.json reachable (HTTP 200)"
else
  echo "⚠️  manifest.json returned HTTP $HTTP_CODE — check the bucket public-access / custom-domain setup."
fi

echo ""
echo "✅ Release $VERSION published."
echo "   Users on older versions will see the update within 24h (or on next 'Check for Updates')."
echo ""
echo "Next: commit the project.yml version bump and push:"
echo "   git add project.yml"
echo "   git commit -m \"Release: bump version to $VERSION\""
echo "   git push nexus main"
