# Prayer Times · مواقيت الصلاة

A NexusIsland extension that surfaces daily prayer times for a user-configured
location, shows a live countdown to the next prayer beside the notch, and sends
notifications before and at each prayer.

## What it does

- Fetches the day's timings from the **Aladhan API** (`api.aladhan.com`) — free,
  no API key. Six calculation methods supported (Umm Al-Qura default).
- Shows a **minimal-compact chip** beside the notch: prayer icon + Arabic name +
  countdown (`الفجر 2h 12m`).
- Sends a **pre-prayer reminder** N minutes ahead (configurable, 0–30).
- Sends an **at-prayer notification** as each prayer enters.
- Includes the **Hijri date** in the at-prayer notification body.

## Configure (Settings → Extensions → Prayer Times)

| Field | Purpose |
|---|---|
| Latitude / Longitude | Your city coordinates (default: Riyadh 24.71, 46.68) |
| Calculation method | Umm Al-Qura, MWL, Egyptian, Gulf, Karachi, ISNA |
| Notify minutes before | Pre-prayer reminder lead time (0 disables) |
| Play adhan sound | Haptic feedback at prayer time (audio asset TBD) |

## Enable

Newly discovered extensions default to **disabled**. Enable in
**Settings → Extensions** (or the menu-bar Modules submenu).

## Permissions

`network` (Aladhan API), `notifications` (feed + reminders).

## Mode

Notification-feed extension — surfaces in the shared Notifications module and as
a minimal-compact side chip; hidden from module slots.

## Data source

`GET https://api.aladhan.com/v1/timings/{yyyy-MM-dd}?latitude=&longitude=&method=`
Response: `data.timings.{Fajr,Sunrise,Dhuhr,Asr,Maghrib,Isha}` (24h "HH:MM"),
`data.date.hijri` (Arabic day/month/year), `data.meta.timezone`.

## Ship bundled

Add `prayer-times` to the `postCompileScripts` rsync list in `project.yml`.
