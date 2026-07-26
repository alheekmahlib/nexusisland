# Cloudflare R2 — Update Hosting

This folder contains everything needed to host NexusIsland auto-updates on
Cloudflare R2 instead of GitHub Releases. R2 is used because GitHub is blocked
in some regions where users need to receive updates.

## Why R2 (not Pages, not GitHub Releases)

| Requirement | GitHub Releases | Cloudflare Pages | Cloudflare R2 |
|---|---|---|---|
| Blocked in some regions | ✗ | ✓ | ✓ |
| Single-file size limit | none | 25 MiB | none (practical) |
| Free egress | ✓ | ✓ | ✓ |
| Custom domain | ✗ | ✓ | ✓ |
| CORS support | via `Access-Control-Allow-Origin` | via `_headers` | via custom domain (R2 default) |

A signed `.dmg` is typically 50–150 MiB, which rules out Pages/Workers static
assets (25 MiB cap). R2 has no practical single-object limit.

## One-time setup

### 1. Create the R2 bucket

Dashboard → **R2** → **Create bucket**. Name it `nexusisland-releases`.

### 2. Connect a custom domain

Bucket → **Settings** → **Custom Domains** → **Add**.

Use a subdomain of a zone you already manage on Cloudflare, e.g.
`releases.yourdomain.com`. Cloudflare auto-creates the CNAME and provisions
TLS. Status flips to **Active** in a minute or two.

> The app will read `https://releases.yourdomain.com/manifest.json` and
> download `https://releases.yourdomain.com/NexusIsland-<version>.dmg`.
> Edit `UpdateChecker.manifestURL` in the Swift code to point at your domain.

### 3. Create an R2 API token (for the publish script)

Dashboard → **R2** → **Manage R2 API Tokens** → **Create API Token**.

- Permission: **Object Read & Write**
- Specify bucket: `nexusisland-releases`
- Save the **Access Key ID**, **Secret Access Key**, and **endpoint** (looks
  like `https://<accountid>.r2.cloudflarestorage.com`).

Add them to your local `.env` (never commit):

```
R2_ACCESS_KEY_ID=...
R2_SECRET_ACCESS_KEY=...
R2_ENDPOINT=https://<accountid>.r2.cloudflarestorage.com
R2_BUCKET=nexusisland-releases
```

### 4. Verify public read

After uploading the first `manifest.json` (see `publish-release.sh`), test:

```bash
curl -I https://releases.yourdomain.com/manifest.json
# HTTP/2 200
# content-type: application/json
```

## Files

- `manifest.example.json` — the shape `UpdateChecker.swift` expects. Copy to
  `manifest.json`, edit, and upload to the bucket root.
- `../scripts/publish-release.sh` — builds + signs + notarizes a DMG, then
  uploads both `manifest.json` and the DMG to R2 via the S3-compatible API.

## Update flow

```
User's app (v1.0.0)
    │
    │  every 24h: GET https://releases.yourdomain.com/manifest.json
    │             (cached at Cloudflare edge, ~50ms worldwide)
    ▼
manifest.json { "version": "1.1.0", "url": ".../NexusIsland-1.1.0.dmg", ... }
    │
    │  compare 1.1.0 > 1.0.0  → update available
    ▼
Download DMG → mount → verify codesign+spctl+TeamID → replace + relaunch
```

## Why this is safe

The signature verification in `AutoUpdater.swift` (codesign + spctl + TeamID
match) runs against the downloaded DMG **regardless** of where it came from.
Hosting on R2 vs. GitHub does not lower the security bar — a tampered DMG
uploaded to R2 is still rejected at install time because it will not carry
your Team ID.
