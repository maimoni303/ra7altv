# RA7AlTV

مشغّل IPTV **مجاني ومفتوح المصدر** للآيفون وويندوز وماك. بلا إعلانات وبلا تتبّع.

Free, open-source IPTV player for iPhone, Windows and macOS. No ads, no tracking.

> RA7AlTV مشغّل فقط ولا يوفّر أي قنوات أو محتوى. استخدمه مع اشتراك من مزوّد مرخّص.

## المزايا

- **Xtream Codes** و **M3U** ودليل البرامج **XMLTV**
- البث المباشر، والأفلام، والمسلسلات بمواسمها وحلقاتها
- معاينة مباشرة للقناة ودليل «الآن / التالي»
- المفضلة، و«تابع المشاهدة» من حيث توقفت، والانتقال التلقائي للحلقة التالية
- إعادة اتصال تلقائية عند انقطاع البث
- مشغّل **mpv** يدعم كل الصيغ تقريباً (TS و HLS و MKV و MP4…)
- ثيم **داكن وفاتح** تختار بينهما متى شئت
- عدة اشتراكات، وبياناتها مشفّرة على جهازك فقط (Keychain / Credential Manager)
- قبول خوادم http والشهادات الذاتية الشائعة عند مزوّدي IPTV
- رقم تفعيل يُطلب مرة واحدة على كل جهاز (اختياري)

## التحميل

من صفحة **[Releases → latest](../../releases/tag/latest)**:

| النظام | الملف |
| --- | --- |
| ويندوز 10/11 | `RA7AlTV-Windows.zip` |
| ماك (macOS 10.15+) | `RA7AlTV-macOS.dmg` |
| آيفون (iOS 13+) | `RA7AlTV-iPhone-unsigned.ipa` |

## التثبيت

### ويندوز
1. فك ضغط `RA7AlTV-Windows.zip` في مجلد مثل `C:\RA7AlTV`.
2. شغّل `ra7altv.exe`.
3. إن ظهر تحذير **Windows protected your PC**: اضغط **More info** ثم **Run anyway** (مرة واحدة فقط).

### ماك
1. افتح `RA7AlTV-macOS.dmg` واسحب **RA7AlTV** إلى **Applications**.
2. أول مرة: كليك يمين على التطبيق ← **Open** ← **Open**.
3. إن رفض النظام فتحه، نفّذ في Terminal:
   ```
   xattr -cr /Applications/RA7AlTV.app
   ```

### آيفون
آبل لا تسمح بتشغيل تطبيق غير موقّع، لذلك يُوقَّع بحساب Apple ID الخاص بك:
1. ثبّت **[Sideloadly](https://sideloadly.io)** على ويندوز أو ماك.
2. وصّل الآيفون بالكمبيوتر بالكيبل.
3. اسحب ملف `RA7AlTV-iPhone-unsigned.ipa` إلى Sideloadly، وأدخل Apple ID، ثم **Start**.
4. في الآيفون: **الإعدادات ← عام ← VPN وإدارة الجهاز** ← وثّق حسابك.
5. فعّل **وضع المطوّر**: الإعدادات ← الخصوصية والأمن ← Developer Mode.

> بحساب Apple ID المجاني يلزم إعادة التوقيع كل 7 أيام. بحساب مطوّر آبل (99 دولار سنوياً) يدوم سنة.

## رقم التفعيل

يُضاف كسرّ مخفي في المستودع باسم `RA7AL_ACTIVATION_CODE`
(Settings ← Secrets and variables ← Actions). نظام البناء يحوّله إلى بصمة PBKDF2،
ولا يُكتب الرقم نفسه في الكود ولا في التطبيق. بدون السر يعمل التطبيق بلا شاشة تفعيل.

## البناء

يُبنى تلقائياً عبر GitHub Actions مع كل تحديث على `main`. للبناء محلياً:

```
flutter pub get
bash tool/setup_platforms.sh macos   # أو ios أو windows
flutter run
```

التقنيات: Flutter · media_kit (mpv) · Provider.

## الترخيص

[GPL-3.0](LICENSE)
