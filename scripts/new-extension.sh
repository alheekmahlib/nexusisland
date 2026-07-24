#!/usr/bin/env bash
#
# new-extension.sh — scaffold a new SuperIsland JS extension.
#
# Usage:
#   scripts/new-extension.sh <name> [options]
#
#   scripts/new-extension.sh my-stock-ticker
#   scripts/new-extension.sh prayer-times --permissions network,notifications --feed
#   scripts/new-extension.sh my-tool --dir ExtensionsDev   # dev discovery dir
#
# Generates a ready-to-enable extension folder with:
#   <name>/manifest.json   (id: superisland.<name>, version 0.1.0)
#   <name>/index.js        (registerModule skeleton with compact/expanded/fullExpanded)
#   <name>/settings.json   (one toggle, one text field — easy to extend)
#   <name>/icon.svg        (placeholder monochrome icon)
#   <name>/README.md       (what it does + how to enable)
#
# The new extension is auto-discovered on next launch but defaults to DISABLED
# (per ExtensionManager's opt-in policy). Enable it in Settings → Extensions.
#
set -euo pipefail

# -----------------------------------------------------------------------------
# Args
# -----------------------------------------------------------------------------
NAME=""
PERMISSIONS="storage"
FEED="no"
DIR="Extensions"   # default: repo-local discovery dir

print_usage() {
  cat <<'USAGE'
Usage: scripts/new-extension.sh <name> [options]

Arguments:
  <name>                  Extension folder + id suffix (e.g. "prayer-times" →
                          folder prayer-times, id superisland.prayer-times).
                          Lowercase, words separated by hyphens.

Options:
  --permissions <list>    Comma-separated permissions to grant.
                          Choices: storage, network, media, notifications, usage.
                          Default: storage
  --feed                  Make it a notification-feed extension (hidden from
                          module slots, surfaces in the shared Notifications
                          module). Adds the notifications permission.
  --dir <path>            Where to create the folder. Default: Extensions
                          (repo-local discovery). Use ExtensionsDev for
                          development-only extensions.
  -h, --help              Show this help.

Examples:
  scripts/new-extension.sh my-ticker --permissions network
  scripts/new-extension.sh prayer-times --permissions network,notifications --feed
  scripts/new-extension.sh experiment --dir ExtensionsDev
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) print_usage; exit 0 ;;
    --permissions) PERMISSIONS="${2:-}"; shift 2 ;;
    --feed) FEED="yes"; shift ;;
    --dir) DIR="${2:-}"; shift 2 ;;
    --permissions=*) PERMISSIONS="${1#*=}"; shift ;;
    --dir=*) DIR="${1#*=}"; shift ;;
    -*) echo "Unknown option: $1" >&2; echo >&2; print_usage >&2; exit 2 ;;
    *)
      if [[ -z "$NAME" ]]; then NAME="$1"; else
        echo "Unexpected argument: $1" >&2; exit 2
      fi
      shift ;;
  esac
done

if [[ -z "$NAME" ]]; then
  echo "Error: extension name is required." >&2
  echo >&2
  print_usage >&2
  exit 2
fi

# Validate name: lowercase letters, digits, hyphens; must start with a letter.
if [[ ! "$NAME" =~ ^[a-z][a-z0-9-]*$ ]]; then
  echo "Error: invalid name '$NAME'." >&2
  echo "Use lowercase letters, digits, and hyphens; start with a letter." >&2
  exit 2
fi

# --feed implies the notifications permission.
if [[ "$FEED" == "yes" ]]; then
  case ",${PERMISSIONS}," in
    *,notifications,*) ;;
    *) PERMISSIONS="${PERMISSIONS:+${PERMISSIONS},}notifications" ;;
  esac
fi

# Validate permissions against the allowlist the runtime enforces.
ALLOWED="storage,network,media,notifications,usage"
IFS=',' read -ra PERM_ARR <<< "$PERMISSIONS"
for p in "${PERM_ARR[@]}"; do
  p_trimmed="${p## }"; p_trimmed="${p_trimmed%% }"
  if [[ ",${ALLOWED}," != *",${p_trimmed},"* ]]; then
    echo "Error: unknown permission '$p_trimmed'." >&2
    echo "Allowed: ${ALLOWED}" >&2
    exit 2
  fi
done
# Re-normalize (trim spaces, drop empties).
CLEAN_PERMS=""
for p in "${PERM_ARR[@]}"; do
  p_trimmed="${p## }"; p_trimmed="${p_trimmed%% }"
  [[ -z "$p_trimmed" ]] && continue
  CLEAN_PERMS="${CLEAN_PERMS:+${CLEAN_PERMS},}${p_trimmed}"
done
PERMISSIONS="$CLEAN_PERMS"

# -----------------------------------------------------------------------------
# Paths
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TARGET_DIR="${REPO_ROOT}/${DIR}/${NAME}"

if [[ -d "$TARGET_DIR" ]]; then
  echo "Error: ${DIR}/${NAME} already exists." >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"

# -----------------------------------------------------------------------------
# Display name: title-case the hyphenated name (e.g. "prayer-times" → "Prayer Times")
# -----------------------------------------------------------------------------
display_name() {
  echo "$1" | awk -F'-' '{
    for (i=1; i<=NF; i++) {
      w=$i; printf "%s%s", toupper(substr(w,1,1)), substr(w,2);
      if (i<NF) printf " ";
    }
  }'
}
DISPLAY_NAME="$(display_name "$NAME")"
EXTENSION_ID="superisland.${NAME}"

# -----------------------------------------------------------------------------
# manifest.json
# -----------------------------------------------------------------------------
# Build capabilities block. notificationFeed extensions hide from module slots.
if [[ "$FEED" == "yes" ]]; then
  CAPABILITIES='{
    "compact": false,
    "expanded": false,
    "fullExpanded": false,
    "minimalCompact": false,
    "backgroundRefresh": true,
    "settings": true,
    "notificationFeed": true
  }'
  TRIGGERS='["timer"]'
else
  CAPABILITIES='{
    "compact": true,
    "expanded": true,
    "fullExpanded": true,
    "minimalCompact": false,
    "backgroundRefresh": true,
    "settings": true,
    "notificationFeed": false
  }'
  TRIGGERS='["manual", "timer"]'
fi

# Serialize permissions as a JSON array string.
PERMISSIONS_JSON=$(
  python3 -c "import json,sys; print(json.dumps([p for p in sys.argv[1].split(',') if p]))" "$PERMISSIONS"
)

cat > "${TARGET_DIR}/manifest.json" <<MANIFEST
{
  "id": "${EXTENSION_ID}",
  "name": "${DISPLAY_NAME}",
  "version": "0.1.0",
  "minAppVersion": "1.0.0",
  "main": "index.js",
  "author": {
    "name": "Your Name"
  },
  "description": "${DISPLAY_NAME} extension for SuperIsland.",
  "icon": "icon.svg",
  "license": "MIT",
  "categories": ["productivity"],
  "permissions": ${PERMISSIONS_JSON},
  "capabilities": ${CAPABILITIES},
  "refreshInterval": 1.0,
  "activationTriggers": ${TRIGGERS},
  "defaultEnabled": false
}
MANIFEST

# -----------------------------------------------------------------------------
# index.js — registerModule skeleton
# -----------------------------------------------------------------------------
if [[ "$FEED" == "yes" ]]; then
  INDEX_BODY='function buildCompact() {
  // Notification-feed extensions are hidden from module slots, so compact()
  // is not shown. Return an empty node.
  return View.empty();
}

function buildExpanded() {
  return View.empty();
}

function buildFullExpanded() {
  return View.empty();
}

function tick() {
  // Called on each refresh (refreshInterval). Fetch data and surface it via
  // the shared Notifications module:
  //
  //   SuperIsland.notifications.send({
  //     title: "New ${DISPLAY_NAME} event",
  //     body:  "details…",
  //     tapAction: { type: "openURL", url: "https://example.com" }
  //   });
  //
  // Guard against duplicates by tracking what you have already sent in
  // SuperIsland.store (the @network permission gates http.fetch).
}'
else
  INDEX_BODY='function buildCompact() {
  // Pill view — keep it glanceable. Read live state from your module variables
  // or from SuperIsland.settings.get(...).
  return View.hstack({
    spacing: 6,
    children: [
      View.icon({ name: "sparkles", size: 12, color: "white" }),
      View.text({ value: "${DISPLAY_NAME}", style: "caption", color: "white" })
    ]
  });
}

function buildExpanded() {
  // Drawer view — more detail, plus interactive buttons.
  return View.vstack({
    spacing: 8,
    children: [
      View.text({ value: "${DISPLAY_NAME}", style: "title", color: "white" }),
      View.text({
        value: "Tap the button to trigger an action.",
        style: "caption",
        color: "gray"
      }),
      View.button({
        label: View.text({ value: "Action", style: "body", color: "white" }),
        action: "demo-action"
      })
    ]
  });
}

function buildFullExpanded() {
  // Detail panel — full surface for lists, settings, rich content.
  return View.scroll({
    child: View.vstack({
      spacing: 12,
      children: [
        View.text({ value: "${DISPLAY_NAME}", style: "title", color: "white" }),
        View.text({
          value: "Edit index.js to build this view. Use View.* builders.",
          style: "body",
          color: "gray"
        })
      ]
    })
  });
}

function tick() {
  // Called on each refresh (refreshInterval). Refresh state, then re-render
  // happens automatically from the compact/expanded/fullExpanded callbacks.
  // With the @network permission:
  //   SuperIsland.http.fetch("https://api.example.com/data")
  //     .then(function (res) { return res.json(); })
  //     .then(function (data) { /* update state */ });
}'
fi

cat > "${TARGET_DIR}/index.js" <<INDEX
"use strict";

// ${DISPLAY_NAME} — generated by scripts/new-extension.sh
// Extension id: ${EXTENSION_ID}
//
// Docs: EXTENSIONS-API.md (authoritative), EXTENSIONS.md (overview).
// The SuperIsland.registerModule contract:
//   onActivate / onDeactivate / onAction / onSettingsChanged hooks, plus
//   compact() / expanded() / fullExpanded() / minimalCompact view callbacks
//   that return View.* node trees.

${INDEX_BODY}

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

SuperIsland.registerModule({
  onActivate: function () {
    // Called once when the extension is enabled. Seed any initial state here.
  },

  onDeactivate: function () {
    // Called when the extension is disabled. Clean up timers, etc.
  },

  onAction: function (actionID) {
    // Fired when a user taps a button whose \`action\` === actionID.
    if (actionID === "demo-action") {
      SuperIsland.notifications.send({
        title: "${DISPLAY_NAME}",
        body: "Action received: " + actionID
      });
    }
  },

  onSettingsChanged: function (key, value) {
    // React to a settings.json field change.
  },

  compact: function () {
    return buildCompact();
  },

  expanded: function () {
    return buildExpanded();
  },

  fullExpanded: function () {
    return buildFullExpanded();
  }
});
INDEX

# -----------------------------------------------------------------------------
# settings.json — one toggle + one text field, as a starting point
# -----------------------------------------------------------------------------
cat > "${TARGET_DIR}/settings.json" <<SETTINGS
{
  "fields": [
    {
      "key": "enabled",
      "label": "Enable feature",
      "type": "toggle",
      "default": true
    },
    {
      "key": "label",
      "label": "Display label",
      "type": "text",
      "default": "${DISPLAY_NAME}",
      "placeholder": "Shown in the pill"
    }
  ]
}
SETTINGS

# -----------------------------------------------------------------------------
# icon.svg — simple monochrome placeholder (template image)
# -----------------------------------------------------------------------------
cat > "${TARGET_DIR}/icon.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64" fill="none">
  <rect x="8" y="8" width="48" height="48" rx="12" fill="currentColor" opacity="0.15"/>
  <path d="M32 18 L44 32 L32 46 L20 32 Z" fill="currentColor"/>
</svg>
SVG

# -----------------------------------------------------------------------------
# README.md
# -----------------------------------------------------------------------------
cat > "${TARGET_DIR}/README.md" <<README
# ${DISPLAY_NAME}

A SuperIsland extension. Generated with \`scripts/new-extension.sh\`.

## What it does

TODO: describe the feature.

## Enable

Newly discovered extensions default to **disabled**. Enable in
**Settings → Extensions**, or the menu-bar Modules submenu, then restart
SuperIsland (or toggle the extension off/on).

## Permissions

$(if [[ -n "$PERMISSIONS" ]]; then echo "Granted: \`$PERMISSIONS\`"; else echo "None."; fi)

$(if [[ "$FEED" == "yes" ]]; then echo "## Mode\n\nNotification-feed extension — surfaces in the shared Notifications module, hidden from module slots."; fi)

## Layout

- \`manifest.json\` — id, permissions, capabilities, refreshInterval.
- \`index.js\` — \`SuperIsland.registerModule({...})\` with view callbacks.
- \`settings.json\` — schema for the Settings → Extensions pane.
- \`icon.svg\` — template icon.

## Ship bundled

To bundle this extension in release builds, add its folder name (\`${NAME}\`)
to the \`postCompileScripts\` rsync list in \`project.yml\`.
README

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo "Created extension: ${DIR}/${NAME}"
echo "  id:            ${EXTENSION_ID}"
echo "  permissions:   ${PERMISSIONS:-none}"
echo "  feed mode:     ${FEED}"
echo ""
echo "Next: restart SuperIsland, then enable it in Settings → Extensions."
echo "To ship it bundled, add '${NAME}' to project.yml's postCompileScripts rsync list."
