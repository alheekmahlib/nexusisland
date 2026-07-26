# دليل خطوة بخطوة: إنشاء Cloudflare R2 من الصفر

هذا الدليل يشرح كل خطوة بالتفصيل. اتبعها بالترتيب.

---

## الخطوة 1: تسجيل الدخول

1. افتح المتصفح
2. اذهب لـ: https://dash.cloudflare.com/login
3. سجّل دخولك بحساب Cloudflare الخاص بك

---

## الخطوة 2: الذهاب لقسم R2

في الصفحة الرئيسية، انظر للقائمة الجانبية على اليسار:

- ابحث عن **"R2 Object Storage"** في القائمة
- اضغط عليها

أو اذهب مباشرة لـ:
https://dash.cloudflare.com/?to=/:account/r2/overview

---

## الخطوة 3: تفعيل R2 (أول مرة فقط)

لو كانت أول مرة تدخل R2، سترى صفحة تقول "Get started with R2".

- اضغط زر **"Enable R2 Object Storage"**
- قد يطلب ربط بطاقة ائتمان (لا تقلق: هناك 10 GB مجاناً + 10 مليون طلب شهرياً، لن تدفع شيئاً لتطبيقك)

---

## الخطوة 4: إنشاء الـ bucket

1. اضغط زر **"Create bucket"** (في أعلى اليمين)

2. املأ النموذج بهذه القيم بالضبط:

   - **Bucket name**: `nexusisland-releases`
     (مهم: استخدم هذا الاسم بالضبط، لا يمكن تغييره لاحقاً)

   - **Location**: اختر **Automatic**

   - **Default storage class**: اختر **Standard**

3. اضغط **"Create bucket"**

ستنتقل لصفحة الـ bucket الداخلية.

---

## الخطوة 5: تفعيل الوصول العام (r2.dev URL)

هذه الخطوة حرجة جداً — بدونها التطبيق لن يستطيع تحميل التحديثات.

1. في صفحة الـ bucket، اضغط تبويب **"Settings"** (في الأعلى)

2. انزل لقسم **"Public access"**

3. تحت **"r2.dev URL"** اضغط زر **"Enable"**

4. ستظهر نافذة تأكيد:
   - اكتب كلمة `allow` في الخانة
   - اضغط **"Allow"**

5. بعد لحظات، سيظهر URL الخاص بـ bucket بهذا الشكل:

   `https://pub-ABCDEF12345.r2.dev`

   (الجزء `ABCDEF12345` سيكون مختلفاً لكل حساب)

6. **انسخ هذا ال URL** — ستحتاجه لاحقاً في الكود

---

## الخطوة 6: إنشاء API Token (للرفع من جهازك)

نحتاج مفاتيح وصول لكي يستطيع الـ script على جهازك رفع الملفات لـ R2.

1. في قائمة R2 الجانبية، اضغط **"Manage R2 API Tokens"**

   أو اذهب لـ:
   https://dash.cloudflare.com/?to=/:account/r2/api-tokens

2. اضغط **"Create API token"**

3. املأ النموذج:

   - **Token name**: `nexusisland-publish` (أي اسم تريده)

   - **Permissions**: اختر **"Object Read & Write"**
     (يجب أن يكون Read & Write لنتمكن من الرفع)

   - **Specify bucket(s)**: اختر **"Apply to specific buckets only"**
     ثم اختر: `nexusisland-releases`

   - **TTL**: اتركه **Forever**

4. اضغط **"Create API Token"**

5. تحذير مهم: ستظهر لك 3 قيم، هذه آخر مرة تراها:

   - **Access Key ID** (مثل: `1a2b3c4d5e...`)
   - **Secret Access Key** (مثل: `AbCdEfGh...`)
   - **Endpoint** (مثل: `https://abc123.r2.cloudflarestorage.com`)

6. **انسخ الثلاثة واحفظهم في مكان آمن**

---

## الخطوة 7: ملء ملف .env على جهازك

افتح ملف `.env` الموجود في مجلد المشروع:
`/Users/hawazenmahmood/Documents/GitHub/SuperIsland/.env`

املأ القيم من الخطوات السابقة:

```
# Apple signing (تحتاجها لاحقاً للتوقيع)
APPLE_ID=بريدك@icloud.com
APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx
TEAM_ID=XXXXXXXXXX
SIGNING_IDENTITY=Developer ID Application: Your Name (XXXXXXXXXX)

# Cloudflare R2
R2_ACCESS_KEY_ID=1a2b3c4d5e...           ← من الخطوة 6
R2_SECRET_ACCESS_KEY=AbCdEfGh...          ← من الخطوة 6
R2_ENDPOINT=https://abc123.r2.cloudflarestorage.com  ← من الخطوة 6
R2_BUCKET=nexusisland-releases
R2_PUBLIC_BASE_URL=https://pub-ABCDEF12345.r2.dev    ← من الخطوة 5
```

---

## ماذا يحدث بعد ذلك

بعد إكمال الخطوات 1-7، أعطني:

1. الـ r2.dev URL (من الخطوة 5) — هذا عام (public) ولا بأس بمشاركته
2. سأحدّث الكود وأختبر كل شيء

ملاحظة أمنية: لا تشارك الـ Access Key ID أو Secret Access Key مع أحد. ضعهم في .env فقط.

---

## ملخص سريع

| الخطوة | المكان | النتيجة |
|--------|--------|---------|
| 1 | dash.cloudflare.com | تسجيل الدخول |
| 2 | قائمة R2 | الدخول لقسم R2 |
| 3 | زر Enable R2 | تفعيل R2 (مرة واحدة) |
| 4 | Create bucket | إنشاء `nexusisland-releases` |
| 5 | Settings → r2.dev URL → Enable | الحصول على الـ URL العام |
| 6 | Manage R2 API Tokens → Create | الحصول على 3 مفاتيح |
| 7 | ملف .env على جهازك | حفظ المفاتيح محلياً |

عند الانتهاء، أعطني الـ r2.dev URL فقط، وسأكمل الباقي.
