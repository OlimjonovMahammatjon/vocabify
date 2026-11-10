# 🚀 Vocabify — Google Play Marketga Chiqarish Bo'yicha To'liq Qo'llanma

Ushbu qo'llanma **Vocabify** ilovasini Google Play Console orqali Play Marketga muvaffaqiyatli, xatosiz va birinchi urinishdayoq tasdiqlatib chiqarish uchun tayyorlandi.

---

## 1. Ilova Identifikatorlari va Texnik Talablar

- **Package Name (Application ID):** `com.vocabify.vocabify_app`
- **Minimum SDK:** `21` (Android 5.0 Lollipop — barcha faol qurilmalarning 99.5%+ qamrovi)
- **Target SDK:** `34`+ (Google Play Store talablariga 100% mos)
- **Build Formati:** `.aab` (Android App Bundle — Play Store faqat AAB qabul qiladi)
- **Bildirishnomalar rejimi:** `inexactAllowWhileIdle` (Google Play ning cheklovchi `SCHEDULE_EXACT_ALARM` ruxsatnomasini talab qilmaydi, tekshiruvdan oson o'tadi).

---

## 2. Release Kaliti (Upload Keystore) Yaratish

Play Store uchun dasturni o'z shaxsiy kalitingiz bilan imzolashingiz kerak. Terminalda quyidagi buyruqni bajaring:

```bash
keytool -genkey -v -keystore android/app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
*Eslatma: Kalit parolini (storePassword & keyPassword) eslab qoling va xavfsiz joyda saqlang!*

### `key.properties` faylini yaratish:
`android/key.properties.example` dan nusxa olib, `android/key.properties` faylini oching:
```properties
storePassword=sizning_parolingiz
keyPassword=sizning_parolingiz
keyAlias=upload
storeFile=upload-keystore.jks
```

---

## 3. Production App Bundle (.aab) Yig'ish

Terminalda loyihaning asosiy papkasida quyidagi buyruqni ishga tushiring:

```bash
flutter build appbundle --release
```

Yig'ilgan fayl quyidagi yo'lda hosil bo'ladi:
```text
build/app/outputs/bundle/release/app-release.aab
```

*Joriy versiya: `version: 1.0.3+4`*

Tayyorlangan App Bundle fayli loyiha asosiy papkasida ham tayyorlab qo'yilgan:
👉 `Vocabify.aab` (~57 MB)

---

## 4. Google Play Console Sozlamalari (Checklist)

### A. Ilova tafsilotlari (Main Store Listing):
- **Ilova nomi (App name, max 30 belgi):** `Vocabify: So'z Yodlash & SRS`
- **Qisqa tavsif (Short description, max 80 belgi):**
  > Interaktiv kartalar, interval takrorlash (SM-2), vidjet va so'z janglari.
- **To'liq tavsif (Full description):**
  > Vocabify — xorijiy tillardagi so'zlarni samarali va uzoq muddatli xotirada mustahkamlash uchun zamonaviy yordamchingiz!
  >
  > Asosiy imkoniyatlar:
  > • Ilmiy asoslangan SM-2 interval takrorlash (Spaced Repetition) tizimi;
  > • 📱 Telefon bosh ekrani uchun interaktiv Vidjet (Kun so'zi va takrorlash);
  > • 3D flip kartochkalar va talaffuzni eshitish (TTS);
  > • Yozma mashqlar (Typing mode) va interaktiv testlar (Quiz);
  > • Kunlik o'rganish statistikasi, qiyin so'zlar tahlili va streak hisobi;
  > • To'liq oflayn ishlash va internet paydo bo'lganda avtomatik sinxronlash;
  > • JSON yoki matndan so'zlarni ommaviy import qilish.

### B. Grafik aktivlar (Graphics Assets — `play_store_assets/` papkasida tayyor):
1. **Ilova belgisi (App Icon):** `play_store_assets/app_icon_512x512.png` (512 x 512 px PNG).
2. **Asosiy reklama banneri (Feature Graphic):** `play_store_assets/feature_graphic_1024x500.jpg` (1024 x 500 px ultra-premium banner).
3. **Skrinshotlar (Phone Screenshots):** Telefoningizda olingan 4-6 ta skrinshot (Bosh sahifa, Kartalar, Testlar, Statistika).

### C. Maxfiylik siyosati (Privacy Policy):
Play Console'da `App content` -> `Privacy policy` bo'limiga [PRIVACY_POLICY.md](./PRIVACY_POLICY.md) ning GitHub xomaki (raw) havolasini kiriting:
`https://raw.githubusercontent.com/KamoliddinMirzaboyev/vocabify-mobile/main/PRIVACY_POLICY.md`

### D. Ma'lumotlar xavfsizligi (Data Safety Section):
Play Console anketasida quyidagilarni belgilang:
- **Ma'lumotlar to'planadimi?** Ha (Email, foydalanuvchi nomi, o'rganish statistikasi — faqat hisob xavfsizligi va o'quv jarayoni uchun).
- **Uchinchi shaxslarga beriladimi?** Yo'q (reklama tarmoqlari umuman yo'q).
- **Shifrlanganmi?** Ha, barcha ma'lumotlar tranzitda shifrlangan (HTTPS/TLS).
- **Hisobni o'chirish imkoniyati bormi?** Ha.

### E. Yosh toifasi (Content Rating):
- IAPP / PEGI / ESRB anketasida so'rovnomani to'ldiring:
  - Zo'ravonlik, behayo so'zlar: Yo'q;
  - Reklama: Yo'q;
  - Natija: **3+ (Barcha yoshdagilar uchun mos)**.

---

## 5. Yuklash (Upload) Jarayoni
1. Google Play Console oching: https://play.google.com/console
2. **"Create app"** bosing -> `Vocabify: So'z Yodlash & SRS` nomini yozing.
3. Chap menyudan **Production** (yoki **Internal testing**) bo'limiga kiring.
4. **"Create new release"** tugmasini bosing va loyiha root papkasidagi `Vocabify.aab` faylini yuklang.
5. Grafik aktivlar (`play_store_assets/`) va tavsiflarni to'ldirib, **"Send for review"** tugmasini bosing!

