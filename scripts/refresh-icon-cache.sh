#!/bin/bash
# Refresh macOS icon caches so the new Nexus Island app icon shows up
# in Finder, Dock, Launchpad, Spotlight, the app switcher, and System Settings.
#
# Run from a terminal:
#   bash scripts/refresh-icon-cache.sh
#
# Requires your macOS password (sudo) for the system-level cache clear.

set -e

APP="/tmp/NexusIsland-DD/Build/Products/Debug/NexusIsland.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"

echo "==> 1/4  Re-registering the built app with LaunchServices"
if [ -d "$APP" ]; then
  "$LSREGISTER" -f -R "$APP"
  echo "      registered: $APP"
else
  echo "      (built app not found at $APP — skipping; rebuild first)"
fi

echo "==> 2/4  Clearing user-level icon-services cache"
rm -rfv ~/Library/Caches/com.apple.iconservices.store 2>/dev/null | tail -2 || true

echo "==> 3/4  Clearing SYSTEM-level icon-services cache (needs sudo)"
sudo rm -rfv /Library/Caches/com.apple.iconservices.store 2>/dev/null | tail -2 || true
sudo rm -rfv /System/Library/Caches/com.apple.iconservices.store 2>/dev/null | tail -1 || true

echo "==> 4/4  Restarting Dock / Finder / SystemUIServer"
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true

echo ""
echo "Done. If the old icon still shows anywhere (especially System Settings >"
echo "Applications or Launchpad), RESTART THE MAC — that clears the kernel-level"
echo "icon cache that no command can reach."
