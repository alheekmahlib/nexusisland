# SuperIsland — Development Roadmap

> خارطة طريق تطوير SuperIsland — 19 ميزة جديدة + أساس بنيوي.
> كل ميزة تُعلَّم ✅ عند إكمالها. هذا الملف هو مصدر الحقيقة للتقدّم.

---

## نظرة عامة على النهج

- **حفظ الخطة**: هذا الملف يحتوي على كل المراحل والميزات والترتيب والاعتماديات، لتطبيق طلب "حفظ كل الخطة كي لا ننسى أي شيء". كل ميزة عند إنجازها تُعلَّم ✅.
- **التزام البنية**: كل Module أصلي يتبع نمط `Manager` singleton + `CompactView` + `ExpandedView` + تسجيل في `ModuleType` (`SuperIsland/App/AppState.swift:19`). كل Extension يتبع نمط `manifest.json` + `index.js` يستدعي `SuperIsland.registerModule({...})`.
- **الأفضل لكل ميزة**: Module أصلي عند الحاجة لـ EventKit/IOKit/Audio APIs الخاصة؛ Extension عند الاكتفاء بـ HTTP fetch + تخزين.
- **اختبار قبل الدمج**: بعد Phase 0، كل ميزة جديدة تكتب لها اختبارات قبل اعتمادها.

---

## Phase 0 — الأساس البنيوي (التنفيذ أولاً) 🏗️

تأسيس أرضية تمنع الكسر قبل إضافة 19 ميزة. حالياً يوجد اختبار واحد فقط في المشروع كله.

| الحالة | المهمة | الملفات/الأدوات | الناتج |
|---|---|---|---|
| ✅ | **0.1** إضافة `.swiftlint.yml` + `.swiftformat` | جذر الـ repo، قواعد متوافقة مع كود موجود (no force-unwrap، `@MainActor` على UI) | فحص جودة موحّد |
| ✅ | **0.2** CI workflow للبناء | `.github/workflows/ci.yml` — `xcodegen generate` + `xcodebuild build` + `xcodebuild test` على macOS runner | حماية main من الكسر |
| ✅ | **0.3** نواة Test Suite | `SuperIslandTests/` — اختبارات لـ `AppState` (transitions)، `BatteryManager`، `WeatherManager` (mock)، `ExtensionManifest` (parsing)، `ModuleRefreshScheduler` (توسيع الموجود) | تغطية للنواة |
| ✅ | **0.4** اختبارات Extension runtime | اختبارات لـ `ExtensionJSRuntime` (sandbox: لا `eval`/`Function`)، `ExtensionSandbox`، `ViewNode.from(...)` | حماية sandbox |
| ✅ | **0.5** أداة scaffold للأ extensions | `scripts/new-extension.sh` (أو Swift CLI صغير) تولّد هيكل `manifest.json` + `index.js` من قالب | تسريع إنشاء Extensions لاحقاً |

**التقدير**: 2-3 جلسات عمل | **المخرجات**: اختبارات + CI + lint + أداة scaffold. **مُنجز بالكامل (66 اختباراً تمرّ).**

---

## Phase 1 — مشغل القرآن (Module أصلي) 📿

Module أصلي. التشغيل **سورة كاملة بملف صوتي واحد** لكل (سورة × قارئ)، لا آية بآية.

**البيانات**: AlQuran Cloud API (`https://api.alquran.cloud/v1/surah/{number}/{reciter}`) — يُرجع رابط mp3 للسورة كاملة + نص السورة. لا مفتاح API مطلوب.

| الحالة | المكوّن | الوصف |
|---|---|---|
| ✅ | `SuperIsland/Modules/Quran/QuranManager.swift` | `@MainActor ObservableObject` — يدير السورة الحالية، القارئ، التشغيل/الإيقاف، آخر موضع استماع، آخر سورة، إعدادات القارئ في `@AppStorage` |
| ✅ | `SuperIsland/Modules/Quran/QuranPlayer.swift` | طبقة `AVPlayer` تُشغّل ملف السورة الكامل — حالات `isPlaying`/`progress`/`duration`/`currentPosition`؛ استئناف من آخر موضع عند التوقف |
| ✅ | `SuperIsland/Modules/Quran/QuranReciters.swift` | قائمة القرّاء (9 قرّاء، **بدون السديس**): عبد الباسط، الحصري، المنشاوي، العفاسي، المعيقلي، بصفر، الشريم، الحذيفي، العجمي — كلٌّ مع مُعرّف AlQuran Cloud |
| ✅ | `SuperIsland/Modules/Quran/QuranCompactView.swift` | اسم السورة + القارئ + شريط تقدّم السورة + زر تشغيل/إيقاف |
| ✅ | `SuperIsland/Modules/Quran/QuranExpandedView.swift` | اختيار القارئ + اختيار السورة (114 سورة) + إعادة تشغيل من البداية + قفز لسورة تالية/سابقة |
| ✅ | `SuperIsland/Modules/Quran/QuranFullExpandedView.swift` | قائمة السور الكاملة، آخر مواضع الاستماع لكل سورة، إحصائيات يومية (سور مكتملة) |
| ✅ | التسجيل | إضافة `case quran` في `ModuleType` (`SuperIsland/App/AppState.swift:19`) + المسار في `ExpandedView.swift` + `CompactView` + `FullExpandedView` |
| ✅ | الاختبارات | `QuranModuleTests` — 24 اختباراً تغطّي: قائمة القرّاء (9، بدون السديس)، 114 سورة، التحويل للأرقام العربية، بناء عناوين الصوت، التسجيل في ModuleType |

**الميزات**: 9 قرّاء (بدون السديس)، تشغيل السورة كاملة، انتقال تلقائي للسورة التالية، استئناف من آخر موضع، عرض اسم السورة بالعربية + رقمها، شريط تقدّم، حفظ آخر سورة وقارئ. **مُنجز بالكامل (24 اختباراً تمرّ، البناء ناجح).**

---

## Phase 2 — إضافات عربية/إسلامية 🌙

| الحالة | # | الميزة | النوع | الـ API/المصدر |
|---|---|---|---|---|
| ✅ | 2.1 | **مواقيت الصلاة + تنبيه** | Extension (`notificationFeed`) | Aladhan API المجاني (`api.aladhan.com/v1/timings`) حسب الموقع |
| ✅ | 2.2 | **التقويم الهجري** | تحسين على Calendar الموجود | طبقة تحويل Umm al-Qura بجانب التاريخ الميلادي |
| ✅ | 2.3 | **تعريب كامل + RTL** | تحسين بنيوي | `.xcstrings` String Catalog (280 مفتاح) + دعم RTL + language picker |

**تفاصيل 2.1**: إشعار قبل كل صلاة بدقائق قابلة للضبط، عرض الصلاة القادمة في minimal chip، 6 طرق حساب (أم القرى افتراضياً). ✅
**تفاصيل 2.2**: عرض "15 محرم 1448 هـ" بجانب التاريخ الميلادي في لوحة Calendar. ✅
**تفاصيل 2.3**: 280 مفتاح مُعرّب عبر 20 ملفاً، تبديل لغة (System/English/العربية) من الإعدادات. ✅

**التقدير**: 3 جلسات. **مُنجز بالكامل.**

---

## Phase 3 — إضافات للمبرمج 👨‍💻

| الحالة | # | الميزة | النوع | الـ API/المصدر |
|---|---|---|---|---|
| ☐ | 3.1 | **GitHub PR/Issue Watcher** | Extension (`notificationFeed`) + OAuth عبر `superisland://` | GitHub GraphQL API |
| ☐ | 3.2 | **CI/CD Build Monitor** | Extension | GitHub Actions API |
| ☐ | 3.3 | **Local Dev Servers** | Module أصلي | فحص المنافذ (BSD sockets) |
| ☐ | 3.4 | **Git Branch / Repo Stats** | Module أصلي | `git` CLI |
| ☐ | 3.5 | **Docker Status** | Extension | `docker` CLI / Docker socket |

**ترتيب التنفيذ**: 3.1 → 3.2 → 3.4 → 3.3 → 3.5.
نبدأ بـ 3.1 (الأكثر فائدة يومية). نعتمد على `AIUsageProvider` و`AgentsStatusBridge` كأنماط مرجعية موجودة.

**التقدير**: 4-5 جلسات.

---

## Phase 4 — إضافات الاستخدام اليومي 🏠

| الحالة | # | الميزة | النوع | الـ API/المصدر |
|---|---|---|---|---|
| ☐ | 4.1 | **Stocks/Crypto Ticker** | Extension | Yahoo Finance غير الرسمي / CoinGecko |
| ☐ | 4.2 | **Currency Converter** | Extension | open.er-api.com (مجاني بدون مفتاح) |
| ☐ | 4.3 | **World Clock** | Extension | محلي (Foundation `TimeZone`) |
| ☐ | 4.4 | **Apple Reminders integration** | Module أصلي | EventKit `EKReminder` (يكمّل Calendar) |
| ☐ | 4.5 | **One-click Meeting Join** | تحسين على Calendar | استخراج رابط Meet/Zoom/Teams من نص الحدث |
| ☐ | 4.6 | **Clipboard History** | Module أصلي | `NSPasteboard` + تخزين آمن |
| ☐ | 4.7 | **Countdown / Days-until** | Extension | محلي + تخزين |

**ترتيب التنفيذ**: 4.3 → 4.2 → 4.1 → 4.7 → 4.5 → 4.4 → 4.6 (من الأسهل للأعمق).

**التقدير**: 5-6 جلسات.

---

## Phase 5 — التشطيب والتسليم ✨

| الحالة | المهمة | الوصف |
|---|---|---|
| ☐ | 5.1 | توثيق الميزات الجديدة — تحديث `README.md` + `docs/` + `EXTENSIONS.md` لكل إضافة |
| ☐ | 5.2 | تحديث `project.yml` — إضافة الـ Extensions المُجمَّعة لقائمة `postCompileScripts` rsync |
| ☐ | 5.3 | اختبارات تكامل — اختبار end-to-end لكل Module + Extension |
| ☐ | 5.4 | مراجعة الأداء — التأكد من التزام كل ميزة بـ `ModuleRefreshScheduler` وسياسات الطاقة |
| ☐ | 5.5 | تحديث `ROADMAP.md` النهائي — تعليم كل الميزات ✅ |

---

## قواعد التنفيذ (تُطبَّق طوال المشروع)

1. **كل Phase فرع مستقل** — لا ندمج إلى `main` حتى يكتمل وتمرّ اختباراته.
2. **Test-first للميزات الجوهرية** — Module أصلي بدون اختبار لا يُدمج.
3. **التزام المعايير** — `@MainActor`، لا force-unwrap، تعليقات إنجليزية في الكود (للتوافق مع upstream)، ملتزمون بـ lint.
4. **عدم لمس المنطق الحسّاس للنافذة** — قاعدة "no GeometryReader" في سطح الـ island (`SuperIsland/Views/IslandContainerView.swift:13-15`)، وحجم النافذة المضبوط في الـ compact.
5. **حفظ التقدّم** — تحديث `ROADMAP.md` بعد كل ميزة (تعليم ☐ → ✅).

---

## سجل التقدّم (Progress Log)

| التاريخ | المرحلة | المُنجز |
|---|---|---|
| 2026-07-23 | — | إنشاء `ROADMAP.md`، الموافقة على الخطة |
| 2026-07-23 | Phase 0 | ✅ الأساس البنيوي كاملاً: `.swiftlint.yml` + `.swiftformat` + CI workflow + نواة Test Suite (66 اختباراً تمرّ) + `scripts/new-extension.sh` |
| 2026-07-23 | Phase 1 | ✅ مشغل القرآن: Module أصلي كامل (9 قرّاء بدون السديس، 114 سورة، تشغيل السورة كاملة، انتقال تلقائي، استئناف من آخر موضع) + 24 اختباراً |
| 2026-07-23 | Phase 2 | ✅ إضافات عربية/إسلامية: مواقيت الصلاة (Aladhan API) + التقويم الهجري (HijriDateFormatter + 7 اختبارات) + التعريب الكامل (String Catalog 280 مفتاح، 20 ملف، language picker) |

---

## مخطط المسار المختصر

```
Phase 0 (أساس)  →  Phase 1 (قرآن)  →  Phase 2 (عربي/إسلامي)
                                              ↓
Phase 5 (تشطيب)  ←  Phase 4 (يومي)  ←  Phase 3 (مبرمج)
```
