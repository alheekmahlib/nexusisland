# Nexus Island — إعادة تصميم الواجهة (Phase 1: Design System + Pilot Modules)

**التاريخ:** 2026-07-24
**الحالة:** معتمد (Approved)
**المرحلة:** 1 من سلسلة (1: البنية التحتية + إثبات · 2+: التوسّع لباقي الوحدات)

---

## 1. الخلفية والدوافع

تطبيق **Nexus Island** (المنتج `NexusIsland`، المصدر لا يزال في مجلّد `SuperIsland/`) هو تطبيق macOS بواجهة SwiftUI + AppKit يقلّد الـ Dynamic Island عبر `NSPanel` عائم، بحالات `compact` (200×36) / `expanded` (408×88) / `fullExpanded` (658×180).

**المشكلة الحالية:** لا يوجد نظام تصميم مركزي.
- لا `Color(hex:)`، لا `Theme`، لا `GlassCard` مشترك.
- الألوان والخطوط والمواد مكتوبة يدوياً ومبعثرة عبر ~40 ملف عرض.
- سطح القرص حالياً تدرّج أسود صلب فقط.
- 22 وحدة بلا بروتوكول، موزّعة عبر ثلاث `switch` في `CompactView`/`ExpandedView`/`FullExpandedView`.
- الاعتماديات: Aptabase فقط (لا Lottie/Pow/Charts).

**الهدف:** إعادة تصميم كامل بثيم موحّد مستوحى من **أيقونة التطبيق** + **دليل التصميم** المرفق: وضع داكن، تدرّجات بنفسجي→ماجنتا→برتقالي نابضة، تأثيرات زجاجية (glassmorphism)، ولمسات ذهبية.

## 2. تحليل المصدرين البصريين (الأيقونة + الدليل)

مصدران موحّدان ينتجان عنهما نظام لوني واحد:

### الأيقونة (الثيم المرجعي للتطبيق)
- خلفية: تدرّج شعاعي داكن بنفسجي — حافة `#1A0B2E`، مركز `#2D1B4E` (توهّج).
- رمز النوتش المتموّج: بنفسجي `#B833FF` → برتقالي `#FF6B35`.
- توهّج حوافي: ماجنتا `#E91E63` + برتقالي `#FF9800`.
- نص/إحساس: أبيض/رمادي مع توهّج نيون زجاجي.

### دليل التصميم
- خلفية أساسية `#1A1A2E`، تدرّج أساسي `#6A0DAD`→`#E91E63`→`#FFC107`.
- لكنة ذهبية `#FBA046`.
- نص أساسي `#FFFFFF`، ثانوي `#CCCCCC`.
- حالات: نجاح `#4CAF50`، تحذير `#FFC107`، خطأ `#F44336`.

**الدمج:** نعتمد خلفية بنفسجي داكن `#1A0B2E` (من الأيقونة، أعمق من `#1A1A2E`)، والتدرّج الأساسي `#6A0DAD`→`#E91E63`→`#FFC107` (من الدليل)، مع التوهّج الشعاعي `#2D1B4E`.

## 3. القرارات المعتمدة (User Decisions)

| القرار | الاختيار |
|---|---|
| **التقسيم** | تدريجي — نظام تصميم أولاً، ثم وحدات رائدة، ثم توسّع |
| **المكتبات** | Pow + Swift Charts + Lottie + Rive (مؤجّل بديل SwiftUI) |
| **التدرّج على القرص** | قرص متدرّج كامل في expanded/fullExpanded؛ **compact يبقى أسود** |
| **الوضع** | داكن فقط |
| **الوحدات الرائدة** | Quran + PrayerTimes + NowPlaying + Battery |

### تحفّظ تقني — Rive
دعم Rive (`rive-apple`) لنظام macOS **غير موثّق رسمياً** (موثّق لـ iOS/Android/web/محركات الألعاب). لذلك:
- **خط الأساس:** يُنفَّذ التقدّم التفاعلي المتوهّج بـ SwiftUI `Canvas`/`Shape`.
- **منفذ التبديل:** يُترك `riveProgressBar` كنقطة استبدال لاحقة عند تأكيد التوافق.
- هذا يمنع حظر المرحلة على اعتمادية غير مُتحقَّق منها.

## 4. العمارة — المرحلة 1.1: نظام التصميم `NexusDesign`

مجلّد جديد: `SuperIsland/Utilities/NexusDesign/` — كل البنية التحتية البصرية في مكان واحد.

### 4.1 `NexusPalette` — لوحة الألوان الموحّدة

```swift
enum NexusPalette {
    // الخلفية (من الأيقونة)
    static let background      = Color(hex: "#1A0B2E")
    static let backgroundGlow  = Color(hex: "#2D1B4E")

    // التدرّج الأساسي (من الدليل + الأيقونة)
    static let gradientStart   = Color(hex: "#6A0DAD") // بنفسجي عميق
    static let gradientMid     = Color(hex: "#E91E63") // ماجنتا نابض
    static let gradientEnd     = Color(hex: "#FFC107") // برتقالي/أصفر

    // الأكسسوارات
    static let accentGold      = Color(hex: "#FBA046") // ذهبي (محدود)
    static let neonPurple      = Color(hex: "#B833FF") // من الأيقونة
    static let neonOrange      = Color(hex: "#FF6B35") // من الأيقونة

    // النصوص
    static let textPrimary     = Color(hex: "#FFFFFF")
    static let textSecondary   = Color(hex: "#CCCCCC")
    static let textTertiary    = Color.white.opacity(0.55)

    // الحالات
    static let success         = Color(hex: "#4CAF50")
    static let warning         = Color(hex: "#FFC107")
    static let danger          = Color(hex: "#F44336")
}
```

### 4.2 `Color(hex:)` initializer

مفقود حالياً. يُضاف كـ `extension Color` مع تطبيع:
- يقبل `#RRGGBB` و `#RGB` و `RRGGBB`.
- قناة ألفا اختيارية (`#RRGGBBAA`).
- تطبيع آمن (قيمة خاطئة → أسود شفاف).

### 4.3 `NexusGradient` — التدرّجات

```swift
enum NexusGradient {
    static var primary: LinearGradient      // gradientStart→gradientMid→gradientEnd, قطري
    static var vibrant: LinearGradient      // أعلى تشبّعاً للأكسسوارات
    static var backgroundRadial: RadialGradient // backgroundGlow→background, توهّج مركزي
    static var accentGold: LinearGradient   // ذهبي خفيف
    static func progress(at value: Double) -> LinearGradient // للون ديناميكي حسب التقدّم
}
```

### 4.4 `NexusTypography` — مقياس الطباعة

يستبدل ~150 استدعاءً مكتوباً يدوياً:
```swift
enum NexusTypography {
    static let hero      = Font.system(size: 24, weight: .bold)
    static let subtitle  = Font.system(size: 18, weight: .semibold)
    static let title     = Font.system(size: 15, weight: .semibold)
    static let body      = Font.system(size: 14, weight: .regular)
    static let caption   = Font.system(size: 11, weight: .medium)
    static let numeric   = Font.system(size: 36, weight: .bold)   // مع خيار تدرّج
    static let mono      = Font.system(size: 10, weight: .regular, design: .monospaced)
}
```

### 4.5 `NexusMetrics` — المقاييس

```swift
enum NexusMetrics {
    static let cornerRadiusS: CGFloat = 10
    static let cornerRadiusM: CGFloat = 16
    static let cornerRadiusL: CGFloat = 24
    static let blurStandard: CGFloat  = 20
    static let strokeHairline: CGFloat = 0.5
    static let spacingUnit: CGFloat = 8
}
```
> يحترم ثوابت الزوايا الموجودة في `Constants.swift` (compact 18 / expanded 22 / fullExpanded 40) — لا يُلغيها.

### 4.6 `GlassCard` + `nexusSurface()` — المكوّن الزجاجي

`ViewModifier` كأساس لكل البطاقات (مستوحى من `QuranDesign.quranSurface` لكنه معمم على مستوى التطبيق):

```swift
struct NexusSurface: ViewModifier {
    enum Variant { case filled, outlined }
    var variant: Variant = .filled
    var isActive: Bool = false
    var radius: CGFloat = NexusMetrics.cornerRadiusM
    var gradient: LinearGradient? = nil   // عند تمريره يُطبّق طبقة تدرّج بشفافية 0.3

    func body(content: Content) -> some View {
        content.background(
            ZStack {
                if variant == .filled { Material.ultraThin }
                gradient?.opacity(0.3)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(Color.white.opacity(isActive ? 0.25 : 0.10), lineWidth: isActive ? 1.2 : NexusMetrics.strokeHairline))
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
    }
}
extension View {
    func nexusSurface(...) -> some View { ... }
}
struct GlassCard<Content: View>: View { ... } // wrapper ملائم
```
Variants: `filled` (Material + تدرّج)، `outlined` (حدّ فقط)، ودعم `isActive`.

### 4.7 المكوّنات المشتركة الجديدة

| المكوّن | الغرض | يحلّ محلّ |
|---|---|---|
| `GradientProgressBar` | شريط تقدّم متدرّج متوهّج، أفقي/دائري | `ProgressBar`, `QuranProgressBar`, `PrayerProgressBar`, `QuranHairlineProgress`, `PrayerProgressHairline` |
| `GradientMedallion` | دائرة أيقونة بتدرّج + توهّج | الميداليات المبعثرة في Quran/PrayerTimes |
| `NeonButton` | زر بتدرّج + `scaleEffect(0.9)` عند الضغط + spring | الأزرار المبعثرة |
| `SparklineChart` | خط بياني صغير (Swift Charts) + نقطة متوهّجة | `BatteryHistorySparkline` |
| `GradientTab` | تبويب متدرّج عند التحديد | زرّ التبويب الحالي في `FullExpandedView` |

## 5. المرحلة 1.2 — سطح الـ Island

الملفات: `Views/IslandContainerView.swift`، `Views/FullExpandedView.swift`.

- **Compact (200×36):** **يبقى أسود** (تدرّج `#000 0.98→0.94`). ضروري لوهم الاندماج مع النوتش المعدني الحقيقي على أجهزة notch. لا تغيير هنا.
- **Expanded (408×88) / FullExpanded (658×180):** القرص يتحوّل إلى **قرص متدرّج كامل**:
  - التدرّج الأساسي `NexusGradient.primary` يغطّي القرص قطرياً.
  - طبقة `NexusGradient.backgroundRadial` توهّجية خفيفة في الخلفية.
  - يُحاذى مع شكل `PillShape` وزوايا `Constants` الموجودة (22/40) — لا تغيير للمنطق.
  - يُحافظ على منطق النافذة/الشكل/الحركة الحالي (`IslandContainerView`، `AppState.notchAnimation`).
- **إزالة التكرار:** التدرّج الأسود المكرّر في `FullExpandedView.swift:443-452` و`:514-522` يُدمَج في `NexusPalette`.

## 6. المرحلة 1.3 — الوحدات الرائدة (4 × 3 حالات = 12 واجهة)

تُهاجَر إلى `NexusDesign` وتُعاد تصميمها بصرياً، عبر الـ routers الموجودة (نفس نمط `switch`):

### 6.1 Quran + PrayerTimes (قسم إسلامي)
- `GlassCard` بالتدرّج الأساسي، نصوص عربية بـ `NexusTypography`، أيقونات `GradientMedallion`.
- **Quran:** `GradientProgressBar` متوهّج متحرّك (خط متوهّج + جزيئات بـ `Canvas`)، أيقونة تشغيل/إيقاف `NeonButton`. رسم Lottie اختياري لـ now-playing قرآني.
- **PrayerTimes:** شريط تقدّم بتدرّج يتغيّر لونه مع اقتراب الوقت (`NexusGradient.progress(at:)`)، هالة تنبيه بـ `Canvas`/`Shape` (منفذ Rive لاحق)، قائمة الصلوات بـ `GlassCard`.
- **RTL محفوظ:** `.environment(\.layoutDirection, .rightToLeft)` للنصوص العربية فقط، كما هو الحال الآن.

### 6.2 NowPlaying (الرائد)
- `GlassCard` مع غلاف الألبوم، `GradientProgressBar` (يحلّ محلّ `ProgressBar` المحلي)، أزرار نقل `NeonButton`.
- طيف الصوت (`EqualizerBarsView` الموجود) يُلوَّن بالتدرّج الأساسي.

### 6.3 Battery (بسيط)
- `GlassCard`، أيقونة بطارية بـ `.symbolEffect` (موجود)، لون دلالي (أخضر/أصفر/أحمر/أبيض)، `SparklineChart` للاتجاه (يحلّ محلّ `BatteryHistorySparkline`).

## 7. المرحلة 1.4 — المكتبات والاعتماديات

تحديث `project.yml` (XcodeGen) — إضافة SPM:

| المكتبة | المصدر | توثّق macOS؟ | الاستخدام في المرحلة 1 |
|---|---|---|---|
| **Pow** | `https://github.com/EmergeTools/Pow` من `1.0.0`+ | ✅ macOS 12+ | انتقالات حالات الـ Island، ظهور/اختفاء العناصر |
| **Lottie** | `https://github.com/airbnb/lottie-ios` من `4.4.0`+ | ✅ macOS رسمياً | رسم واحد كإثبات (now-playing قرآني أو هالة صلاة) — ملف `.json` في `Resources/Animations/` |
| **Swift Charts** | مدمج في macOS 13+ | ✅ | `SparklineChart` — `import Charts` فقط |
| **Rive** | مؤجّل | ⚠️ غير موثّق | بديل SwiftUI `Canvas`/`Shape` الآن؛ منفذ تبديل لاحق |

ثم `xcodegen generate` لإعادة توليد `NexusIsland.xcodeproj`.

## 8. المرحلة 1.5 — الحماية والتراجع

- لا تُمسح الملفات القديمة فوراً: التهجير تدريجي مع الاحتفاظ بسلوك الـ routers حتى يكتمل الانتقال.
- **البناء متوقع ناجح** بعد كل مرحلة فرعية: `xcodebuild -scheme NexusIsland -configuration Debug build`.
- **احترام تقليل الحركة:** كل الأنيميشن الجديد تحترم `AppState.shouldReduceMotion` / `shouldReduceAnimations` (تعود إلى `easeOut` قصير).
- **احترام RTL:** النصوص العربية فقط تُجبر RTL؛ التخطيط العام يبقى LTR لتوحيد التقدّم والقوائم.

## 9. النطاق — ما لن تفعله هذه المرحلة

- الـ **18 وحدة المتبقية** (Weather, Stocks, Calendar, Connectivity, GitHub, Docker, DevServers, GitStats, CI Monitor, WorldClock, Currency, Countdown, Reminders, Clipboard, Shelf, Notifications, Teleprompter, VolumeHUD) — مخطّطات لاحقة بعد إثبات الرائد.
- **الوضع الفاتح** — القرار: داكن فقط.
- **بروتوكول وحدات جديد** — يُقيّم بعد اكتمال التوسّع.

## 10. مخرجات المرحلة 1 (Done Criteria)

1. مجلّد `Utilities/NexusDesign/` بنظام تصميم موحّد (palette, hex init, gradients, typography, metrics, GlassCard, 5 مكوّنات).
2. سطح Island متدرّج في expanded/fullExpanded + أسود في compact.
3. 4 وحدات رائدة (Quran, PrayerTimes, NowPlaying, Battery) معاد تصميمها بالكامل بصرياً عبر الحالات الثلاث.
4. Pow + Lottie + Charts مدمجة وعاملة.
5. بناء ناجح: `xcodebuild -scheme NexusIsland` بدون أخطاء.
6. احترام تقليل الحركة و RTL.

## 11. الخطوة التالية

استدعاء مهارة `writing-plans` لتوليد مخطّط التنفيذ القابل للتنفيذ خطوة بخطوة (ملفات بالترتيب، اختبارات بناء عند كل عقدة، نقاط التحقّق).
