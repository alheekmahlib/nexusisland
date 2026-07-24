"use strict";

// Prayer Times — Nexus extension
// id: nexus.prayer-times
//
// Fetches daily prayer times from the Aladhan API (https://aladhan.com) for a
// user-configured location, surfaces the next prayer as a minimal-compact
// side-chip, and sends notifications before and at each prayer time.
//
// Data source: https://api.aladhan.com/v1/timings — free, no API key.
// The extension uses the `notificationFeed` capability, so notifications land
// in the shared Notifications module; the minimal-compact chip shows a live
// countdown to the next prayer.

// ---------------------------------------------------------------------------
// Prayer definitions
// ---------------------------------------------------------------------------

// The five obligatory prayers plus Sunrise (for the Fajr→Sunrise gap).
// Each key matches the Aladhan `data.timings` field.
var PRAYERS = [
  { key: "Fajr",    ar: "الفجر",     icon: "sun.haze.fill" },
  { key: "Sunrise", ar: "الشروق",    icon: "sunrise.fill" },
  { key: "Dhuhr",   ar: "الظهر",     icon: "sun.max.fill" },
  { key: "Asr",     ar: "العصر",     icon: "sun.max.fill" },
  { key: "Maghrib", ar: "المغرب",    icon: "sunset.fill" },
  { key: "Isha",    ar: "العشاء",    icon: "moon.stars.fill" }
];

// ---------------------------------------------------------------------------
// State (in-memory; re-derived each refresh)
// ---------------------------------------------------------------------------

var todaysTimes = null;      // { Fajr: "05:12", Dhuhr: "...", ... }
var todaysDateKey = "";      // "yyyy-MM-dd" for the loaded timings
var todaysHijri = "";        // "15 محرم 1448"
var notifiedKeys = {};       // { "Fajr": true, "Fajr:pre": true } — avoid dupes
var pollTimer = null;
var fetchInFlight = false;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function settingStr(key, fallback) {
  var v = Nexus.settings.get(key);
  return (v === null || v === undefined || v === "") ? fallback : String(v);
}

function settingNum(key, fallback) {
  var raw = Nexus.settings.get(key);
  if (raw === null || raw === undefined || raw === "") return fallback;
  var n = Number(raw);
  return Number.isFinite(n) ? n : fallback;
}

function settingBool(key, fallback) {
  var v = Nexus.settings.get(key);
  if (typeof v === "boolean") return v;
  if (v === null || v === undefined) return fallback;
  if (typeof v === "number") return v !== 0;
  if (typeof v === "string") return v.toLowerCase() === "true";
  return fallback;
}

// Location + calculation config.
function config() {
  return {
    lat: settingNum("latitude", 24.7136),
    lng: settingNum("longitude", 46.6753),
    method: settingStr("calcMethod", "4"),
    notifyBefore: settingNum("notifyBefore", 10),
    adhanEnabled: settingBool("adhanEnabled", false)
  };
}

// Today's date as "yyyy-MM-dd" in the user's locale.
function todayKey() {
  var d = new Date();
  var m = (d.getMonth() + 1);
  var day = d.getDate();
  return d.getFullYear() + "-" + (m < 10 ? "0" : "") + m + "-" + (day < 10 ? "0" : "") + day;
}

// Convert "HH:MM" (24h, Aladhan format) to a Date for today.
function timeStringToDate(hhmm) {
  var parts = String(hhmm).split(":");
  var h = parseInt(parts[0], 10);
  var m = parseInt(parts[1], 10);
  if (!Number.isFinite(h) || !Number.isFinite(m)) return null;
  var d = new Date();
  d.setHours(h, m, 0, 0);
  return d;
}

// "3h 12m" or "12m" or "now".
function humanCountdown(ms) {
  if (ms < 0) ms = 0;
  var totalMin = Math.floor(ms / 60000);
  if (totalMin <= 0) return "now";
  var h = Math.floor(totalMin / 60);
  var m = totalMin % 60;
  if (h > 0) return h + "h " + m + "m";
  return m + "m";
}

// Find the next prayer (and the current one, if within its window).
function nextPrayer() {
  if (!todaysTimes) return null;
  var now = Date.now();

  for (var i = 0; i < PRAYERS.length; i++) {
    var p = PRAYERS[i];
    var t = todaysTimes[p.key];
    if (!t) continue;
    var date = timeStringToDate(t);
    if (!date) continue;
    var ts = date.getTime();

    if (ts > now) {
      // Next upcoming prayer.
      return { prayer: p, date: date, msUntil: ts - now, isNext: true };
    }
  }

  // All of today's prayers have passed → next is tomorrow's Fajr.
  // Approximate using today's Fajr + 24h (good enough for the countdown chip;
  // the next refresh will reload fresh timings after midnight).
  var fajr = todaysTimes["Fajr"];
  if (fajr) {
    var d = timeStringToDate(fajr);
    if (d) {
      d.setDate(d.getDate() + 1);
      return { prayer: PRAYERS[0], date: d, msUntil: d.getTime() - now, isNext: true };
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Fetch today's timings
// ---------------------------------------------------------------------------

function fetchTimings() {
  if (fetchInFlight) return;
  var cfg = config();
  var key = todayKey();
  if (todaysTimes && todaysDateKey === key) return; // already loaded for today

  fetchInFlight = true;
  var url = "https://api.aladhan.com/v1/timings/" + key +
            "?latitude=" + cfg.lat + "&longitude=" + cfg.lng +
            "&method=" + cfg.method;

  Nexus.http.fetch(url)
    .then(function (res) { return res.json(); })
    .then(function (json) {
      fetchInFlight = false;
      var data = json && json.data;
      if (!data || !data.timings) return;

      todaysTimes = data.timings;
      todaysDateKey = key;
      notifiedKeys = {}; // reset per-day notification guards

      // Capture the Hijri date string for display.
      var hijri = data.date && data.date.hijri;
      if (hijri) {
        var day = hijri.day || "";
        var month = (hijri.month && hijri.month.ar) || "";
        var year = hijri.year || "";
        todaysHijri = (day + " " + month + " " + year).trim();
      }
    })
    .catch(function (err) {
      fetchInFlight = false;
      Nexus.console.error("Prayer Times fetch failed: " + (err && err.message));
    });
}

// ---------------------------------------------------------------------------
// Notification logic
// ---------------------------------------------------------------------------

function checkAndNotify() {
  if (!todaysTimes) return;
  var cfg = config();
  var now = Date.now();

  PRAYERS.forEach(function (p) {
    // Skip Sunrise — it's informational, not a prayer to notify about.
    if (p.key === "Sunrise") return;
    var t = todaysTimes[p.key];
    if (!t) return;
    var date = timeStringToDate(t);
    if (!date) return;
    var ts = date.getTime();

    // Pre-prayer reminder (cfg.notifyBefore minutes ahead).
    if (cfg.notifyBefore > 0) {
      var preKey = p.key + ":pre";
      var preTs = ts - cfg.notifyBefore * 60000;
      if (now >= preTs && now < ts && !notifiedKeys[preKey]) {
        notifiedKeys[preKey] = true;
        var mins = cfg.notifyBefore;
        Nexus.notifications.send({
          title: p.ar + " بعد " + mins + " دقيقة",
          body: "حان وقت صلاة " + p.ar + " خلال " + mins + " دقيقة",
          tapAction: { type: "openURL", url: "" }
        });
      }
    }

    // At-prayer notification.
    if (now >= ts && now < ts + 60000 && !notifiedKeys[p.key]) {
      notifiedKeys[p.key] = true;
      Nexus.notifications.send({
        title: "حان الآن وقت صلاة " + p.ar,
        body: todaysHijri ? "التاريخ الهجري: " + todaysHijri : "",
        tapAction: { type: "openURL", url: "" }
      });
      if (cfg.adhanEnabled) {
        // A subtle haptic; full adhan audio would need a bundled asset.
        Nexus.playFeedback("success");
      }
    }
  });
}

// ---------------------------------------------------------------------------
// Refresh tick — runs every minute via the timer trigger
// ---------------------------------------------------------------------------

function tick() {
  // Reload timings at day rollover.
  if (todaysDateKey !== todayKey()) {
    fetchTimings();
  } else if (!todaysTimes && !fetchInFlight) {
    fetchTimings();
  }
  checkAndNotify();
}

// ---------------------------------------------------------------------------
// View callbacks (notificationFeed → only minimalCompact is shown)
// ---------------------------------------------------------------------------

Nexus.registerModule({
  onActivate: function () {
    // Fetch immediately, then poll every minute for precise notifications.
    fetchTimings();
    pollTimer = setInterval(function () { tick(); }, 60 * 1000);
  },

  onDeactivate: function () {
    if (pollTimer) { clearInterval(pollTimer); pollTimer = null; }
  },

  onAction: function (actionID) {
    // No interactive buttons in this feed extension.
  },

  onSettingsChanged: function (key, value) {
    // Location or method changed → reload timings.
    if (key === "latitude" || key === "longitude" || key === "calcMethod") {
      todaysTimes = null;
      todaysDateKey = "";
      fetchTimings();
    }
  },

  // Notification-feed extensions are hidden from module slots, so these return
  // a trivial node. There's no View.empty() in the runtime; an empty zstack is
  // the canonical "render nothing" node.
  compact: function () { return View.zstack([]); },
  expanded: function () { return View.zstack([]); },
  fullExpanded: function () { return View.zstack([]); },

  // The side chip beside the notch: next prayer + countdown.
  // NOTE: the runtime's builder signatures are positional, not object-literal:
  //   View.icon(name, opts)        — name first, then opts
  //   View.text(value, opts)       — value first, then opts
  minimalCompact: {
    leading: function () {
      var next = nextPrayer();
      if (!next) return View.text("", { style: "caption", color: "white" });
      return View.icon(next.prayer.icon, { size: 12, color: "white" });
    },
    trailing: function () {
      var next = nextPrayer();
      if (!next) return View.text("—", { style: "caption", color: "white" });
      var label = next.prayer.ar + " " + humanCountdown(next.msUntil);
      return View.text(label, { style: "caption", color: "white" });
    },
    precedence: function () {
      // Show the chip whenever we have timings; 0 hides it.
      return todaysTimes ? 1 : 0;
    }
  }
});
