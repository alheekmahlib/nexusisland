# Security Policy & Threat Model

This document records the security posture of **Nexus Island**, the design
trade-offs behind it, and the controls that are (and are not) in place. It is
intended for contributors and reviewers, not end users.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security problems. Instead,
email the maintainer privately so a fix can be coordinated before disclosure.

---

## 1. App Sandbox — intentionally NOT enabled

macOS App Sandbox (`com.apple.security.app-sandbox`) is **not** enabled for
Nexus Island. This is a deliberate decision, not an oversight, because core
features require capabilities that the sandbox forbids without broad temporary
exceptions (which largely negate the sandbox's value):

| Capability | Where used | Sandbox implication |
|---|---|---|
| `CGEvent.tapCreate` (system-wide event tap) | `MediaKeyInterceptor`, `EmojiPickerManager` | Blocked by sandbox; needs Accessibility grant anyway |
| Arbitrary `Process()` spawning | `GitHubManager`, `GitStatsModels`, `BatteryManager`, `NotificationManager` (`log show`), `AutoUpdater` (`hdiutil`/`ditto`/`codesign`), Node.js extension host | Blocked by sandbox |
| `NSAppleScript` against arbitrary apps | `NowPlayingManager`, `VolumeManager` | Blocked by sandbox (`com.apple.security.automation.apple-events` covers only targeted apps) |
| Reading arbitrary repo paths for Git stats | `GitStatsModels`, `GitHubManager` | Blocked by sandbox without user-selected file access per file |

Because every one of these would need a temporary exception, the sandbox would
be a leaky sieve rather than a real boundary. The chosen posture is therefore:
**run unsandboxed, but harden each privileged surface individually** (see
sections below).

If a future version drops any of the above features, sandboxing should be
revisited.

## 2. Hardened Runtime

`ENABLE_HARDENED_RUNTIME = YES` is set in `project.yml`. This enforces library
validation, disables `DYLD` injection, and is required for notarization.

## 3. Auto-updater — signature verification

The updater (`AutoUpdater.swift`) refuses to install a downloaded update unless:

1. `codesign --verify --deep --strict --verbose=2 <candidate>` exits 0,
2. `spctl --assess --type execute --verbose <candidate>` exits 0 (Gatekeeper
   accepts the bundle — implies notarization tick for Developer ID apps), and
3. The candidate's `TeamIdentifier` (from `codesign -dvv`) **equals** the
   running app's `TeamIdentifier`.

A mismatch raises `UpdateError.signatureMismatch` and the update is aborted
before `ditto` runs. The replacement shell script receives its arguments via
environment variables rather than string interpolation, eliminating shell
injection from `hdiutil`-parsed mount points or release URLs.

**Residual risk:** none of this helps if the maintainer's Developer ID key is
compromised. Revoke and re-issue in that case.

### Update source — Cloudflare R2 (not GitHub Releases)

Update metadata and the DMG itself are hosted on Cloudflare R2 behind a
custom domain, not on GitHub Releases. GitHub is blocked in some regions
where users need to receive updates; R2 has global edge availability and free
egress.

The app fetches a small `manifest.json`:

```json
{
  "version": "1.2.0",
  "downloadURL": "https://releases.example.com/NexusIsland-1.2.0.dmg",
  "releaseNotes": ["..."],
  "minimumOSVersion": "14.0",
  "publishedAt": "2026-07-26T12:00:00Z"
}
```

Security does **not** depend on R2 being trusted. Even if an attacker
compromised the R2 bucket (or the custom domain) and swapped in a malicious
DMG, the codesign + spctl + TeamID checks above would reject it — the
attacker cannot sign with the maintainer's Developer ID. R2 is purely a
delivery optimization.

## 4. Secret storage — Keychain

OAuth access tokens, API keys, and API secrets for integrations (Linear,
Last.fm, future providers) are stored in the **macOS Keychain**
(`KeychainStore.swift`, `kSecClassGenericPassword`), not in `UserDefaults`.

Only non-secret metadata (provider name, account id, display name) remains in
`UserDefaults` for UI use.

## 5. Extension sandbox — advisory, not a hard boundary

The JavaScriptCore sandbox in `ExtensionSandbox.swift` (`delete globalThis.eval`,
`delete globalThis.Function`) is **advisory only**. JavaScriptCore cannot
prevent a determined extension from reconstructing `Function` via prototype
chains. Treat installed extensions as running with the app's full privileges.

Mitigations in place:
- `NexusIsland.openURL` only accepts `http`, `https`, and `mailto` schemes
  (no `file://`, no `data:`).
- `NexusIsland.http.fetch` requires the `network` permission in the manifest.
- Extension manifests are validated against a strict `id` pattern before
  installation to prevent path traversal.

Future hardening (out of current scope): run each extension in a separate
`Process` with its own sandbox profile and IPC channel.

## 6. Network

All outbound network traffic uses HTTPS where the remote supports it. The
update feed (`UpdateChecker.swift`) is HTTPS to `api.github.com`.

## 7. Analytics

Analytics (Aptabase) is initialized at launch with a compiled-in key. It is
designed to be privacy-preserving (no user IDs, no event payloads). Future
work: gate `Analytics.start()` behind an explicit opt-in toggle in Settings.
