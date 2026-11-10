# 📚 Vocabify Mobile App (Flutter)

Vocabify PWA ilovasining to'liq 1:1 formatda Flutterda yaratilgan zamonaviy mobil ilovasi (iOS & Android).

---

## 🚀 Asosiy imkoniyatlar

### 1. 🔐 Supabase Autentifikatsiya & Foydalanuvchi Profili
- Email & Parol orqali kirish (Sign in) va ro'yxatdan o'tish (Sign up)
- Profil ma'lumotlari: ism, kunlik maqsad (so'zlar soni), avatarlar
- Xavfsiz sessiya saqlanishi va avtomatik kirish
- Tizimdan chiqish (Sign out)

### 2. 🗂️ To'plamlar & Lug'at Boshqaruvi (Decks & Cards)
- Yangi to'plam yaratish: 10 ta emoji belgilari va 5 ta maxsus rang tanlash
- So'zlar ro'yxati, real-time qidiruv (Search)
- Yangi so'z qo'shish va tahrirlash
- **AI yordamchisi**: Inglizcha so'z kiritilganda `ai-card-helper` orqali avtomatik tarjima, talaffuz (IPA) va misol gaplarni to'ldirish
- Har bir so'z uchun audio talaffuz (TTS)
- So'zlarni va to'plamlarni o'chirish

### 3. 🧠 Aqlli Takrorlash (SM-2 Spaced Repetition Flashcards)
- Ilmiy asoslangan SM-2 (SuperMemo-2) oraliqli takrorlash algoritmi
- **2 xil rejim**:
  1. **Kartochka rejimi**: 3D flip karta animatsiyasi, audio talaffuz, "Bilmayman" (qayta ko'rish) va "Bilaman" (kunlik oraliqni hisoblash)
  2. **Yozish rejimi (Yozib yodlash)**: Misol gapda so'z yashiriladi, foydalanuvchi klaviaturada inglizcha so'zni yozadi, ko'p bosqichli "Yordam" (Hint) tugmasi, to'g'ri/noto'g'ri tekshirish va audio fikr
- Sessiya yakunida konfetti/medal natijalari: aniqlik %, bilganlar, bilmaganlar va streak yangilanishi

### 4. 🎧 Eshitib Yodlash (Listen & Learn Mode)
- To'plamdagi so'zlarni ketma-ket avtomatik o'qib beruvchi audio pleyer
- Inglizcha so'zni o'qiydi -> pauza -> O'zbekcha tarjimasini o'qiydi -> keyingi so'zga o'tadi
- Ekran pastida suzuvchi mini-player paneli

### 5. 🎯 Viktorina (Interactive Quiz)
- Quiz sozlamalari: yo'nalish tanlash (**EN → UZ** yoki **UZ → EN**)
- Har bir savol uchun 30 soniyalik teskari hisoblash taymeri
- To'plamdagi boshqa so'zlardan hosil qilingan 4 ta variant (A, B, C, D)
- Audio tinglash imkoniyati
- To'g'ri/noto'g'ri javoblarni yashil va qizil rangda bir zumda ko'rsatish
- Natijalar oynasi: Foiz ko'rsatkichi, baholash emojisi (🏆, 🎉, 👍, 📚), to'liq javoblar tahlili, qayta boshlash

### 6. 📊 Statistika & Haftalik Grafika
- Joriy streak (olov belgisi) va eng uzun streak
- Kunlik maqsad bajarilish progress bari
- Bugun takrorlanadigan, o'rganilayotgan va mustahkam o'zlashtirilgan so'zlar hisobi
- **Ko'p xato qilingan so'zlar**: Qiyin so'zlarni alohida aniqlash va tahlil qilish
- **So'nggi 7 kunlik faoliyat**: `fl_chart` asosidagi interaktiv ustunli grafik
- O'zlashtirish bosqichlari (Yangi, O'rganilmoqda, Mustahkam)
- Baholash taqsimoti (Yana, Qiyin, Yaxshi, Oson)

### 7. 📦 JSON Import & Export
- Ko'p so'zlarni bir vaqtda JSON orqali yuklash
- `.json` fayllarni to'g'ridan-to'g'ri yuklash
- Haqiqiy vaqtda JSON tekshiruvi va so'zlarni oldindan ko'rish
- To'plamdagi barcha so'zlarni `.json` formatda eksport qilish va ulashish (Share)

### 8. ⚡ Offline-First & Outbox Queue
- Internet uzilganda ham barcha amallar (so'z qo'shish, o'chirish, takrorlash natijalari) kechiktirmasdan bajariladi
- Kutilayotgan amallar local outbox navbatiga saqlanadi
- Aloqa tiklanganda barcha ma'lumotlar fonda avtomatik sinxronizatsiya qilinadi

### 9. 🎨 UI/UX & Dizayn
- Navy brend ranglar palitrasi (`#1e2d4a` / `#4f75b3`)
- Google Fonts (Inter) zamonaviy tipografiyasi
- Tungi (Dark) va Yorug' (Light) mavzularni qo'llab-quvvatlash
- Yumshoq soyalar, burchaklar va 4 ta qulay bo'limli Bottom Navigation Bar

---

## 🛠️ Loyiha tuzilishi

```
Vocabify app/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart
│   │   │   ├── app_constants.dart
│   │   │   └── app_theme.dart
│   │   ├── services/
│   │   │   ├── supabase_service.dart
│   │   │   ├── offline_queue_service.dart
│   │   │   ├── cache_service.dart
│   │   │   └── tts_service.dart
│   │   └── utils/
│   │       ├── srs.dart
│   │       └── helpers.dart
│   ├── models/
│   │   ├── profile_model.dart
│   │   ├── deck_model.dart
│   │   ├── card_model.dart
│   │   ├── review_model.dart
│   │   └── stats_data_model.dart
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   ├── theme_provider.dart
│   │   ├── decks_provider.dart
│   │   ├── cards_provider.dart
│   │   ├── study_provider.dart
│   │   ├── quiz_provider.dart
│   │   └── stats_provider.dart
│   └── screens/
│       ├── auth/
│       │   └── auth_screen.dart
│       ├── main_navigation_screen.dart
│       ├── home/
│       │   └── home_screen.dart
│       ├── decks/
│       │   ├── decks_screen.dart
│       │   ├── deck_detail_screen.dart
│       │   └── card_form_screen.dart
│       ├── study/
│       │   └── study_screen.dart
│       ├── quiz/
│       │   ├── quiz_setup_screen.dart
│       │   ├── quiz_play_screen.dart
│       │   └── quiz_results_screen.dart
│       ├── stats/
│       │   └── stats_screen.dart
│       ├── profile/
│       │   └── profile_screen.dart
│       └── bulk_import/
│           └── bulk_import_screen.dart
├── assets/
│   └── images/
│       ├── hero-study.png
│       ├── vocabifylogo.png
│       └── app_icon.png
├── supabase/
│   └── migrations/
└── pubspec.yaml
```

---

## 📲 Ishga tushirish

1. Bog'liqliklarni o'rnatish:
   ```bash
   cd "/Users/kamoliddin/Desktop/Loyihalar/Vocabify app"
   flutter pub get
   ```

2. Supabase loyihasini link qilib migratsiyalarni qo'llash:
   ```bash
   npx supabase link --project-ref YOUR_PROJECT_REF
   npx supabase db push
   ```

3. Ilovani emulyator yoki qurilmada ishga tushirish:
   ```bash
   flutter run
   ```

4. APK yaratish (Android):
   ```bash
   flutter build apk --release
   ```

5. iOS uchun yig'ish:
   ```bash
   flutter build ios --release
   ```
