import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class ExtractedWordItem {
  String word;
  String translation;
  String? pronunciation;
  String? definition;
  String? example;
  bool isSelected;

  ExtractedWordItem({
    required this.word,
    required this.translation,
    this.pronunciation,
    this.definition,
    this.example,
    this.isSelected = true,
  });

  factory ExtractedWordItem.fromJson(Map<String, dynamic> json) {
    return ExtractedWordItem(
      word: (json['word'] as String? ?? '').trim(),
      translation: (json['translation'] as String? ?? '').trim(),
      pronunciation: json['pronunciation'] as String?,
      definition: json['definition'] as String?,
      example: (json['example'] ?? json['example_sentence']) as String?,
      isSelected: true,
    );
  }

  Map<String, dynamic> toJson() => {
    'word': word,
    'translation': translation,
    'pronunciation': pronunciation,
    'definition': definition,
    'example': example,
  };
}

class AiScanResult {
  final String suggestedDeckName;
  final List<ExtractedWordItem> words;
  final String providerName;
  final String modelName;

  AiScanResult({
    required this.suggestedDeckName,
    required this.words,
    this.providerName = 'Groq AI',
    this.modelName = 'qwen/qwen3.8-27b',
  });
}

enum ScanFocusMode {
  highlighted, // Faqat belgilangan / tagiga chizilgan
  vocabularyList, // Lug'at daftari
  allKeyWords, // Butun matndagi yangi so'zlar
}

enum AiProvider {
  groq, // Groq LPU (Primary - Ultra-fast & smart vision)
  gemini, // Google Gemini Vision (Alternative)
}

class AiScanService {
  AiScanService._();
  static final AiScanService instance = AiScanService._();

  static const String _userGroqApiKeyPref = 'vocabify_user_groq_api_key';
  static const String _userGeminiApiKeyPref = 'vocabify_user_gemini_api_key';
  static const String _activeProviderPref = 'vocabify_active_ai_provider';

  // Primary production vision model on Groq
  static const String defaultGroqVisionModel = 'qwen/qwen3.8-27b';
  static const List<String> fallbackGroqModels = [
    'qwen/qwen3.8-27b',
    'meta-models/muse-spark-open',
  ];

  /// Returns user-configured Groq key or AppConstants default
  Future<String> getGroqApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final custom = prefs.getString(_userGroqApiKeyPref);
      if (custom != null && custom.trim().isNotEmpty) {
        return custom.trim();
      }
    } catch (_) {}
    return AppConstants.groqApiKey;
  }

  Future<void> saveGroqApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key.trim().isEmpty) {
      await prefs.remove(_userGroqApiKeyPref);
    } else {
      await prefs.setString(_userGroqApiKeyPref, key.trim());
    }
  }

  /// Returns user-configured Gemini key or AppConstants default
  Future<String> getGeminiApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final custom = prefs.getString(_userGeminiApiKeyPref);
      if (custom != null && custom.trim().isNotEmpty) {
        return custom.trim();
      }
    } catch (_) {}
    return AppConstants.geminiApiKey;
  }

  Future<void> saveGeminiApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key.trim().isEmpty) {
      await prefs.remove(_userGeminiApiKeyPref);
    } else {
      await prefs.setString(_userGeminiApiKeyPref, key.trim());
    }
  }

  // Alias for backward compatibility
  Future<String> getApiKey() => getGroqApiKey();
  Future<void> saveCustomApiKey(String key) => saveGroqApiKey(key);

  Future<AiProvider> getActiveProvider() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_activeProviderPref);
      if (saved == 'gemini') return AiProvider.gemini;
    } catch (_) {}
    return AiProvider.groq;
  }

  Future<void> setActiveProvider(AiProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _activeProviderPref,
      provider == AiProvider.gemini ? 'gemini' : 'groq',
    );
  }

  Future<bool> hasAnyApiKey() async {
    final groq = await getGroqApiKey();
    if (groq.isNotEmpty) return true;
    final gemini = await getGeminiApiKey();
    return gemini.isNotEmpty;
  }

  /// Scans image using Groq (primary ultra-fast vision model) or Gemini fallback
  Future<AiScanResult> scanImage({
    required File imageFile,
    ScanFocusMode focusMode = ScanFocusMode.highlighted,
    String? extraInstructions,
    AiProvider? preferredProvider,
  }) async {
    final bytes = await imageFile.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('Rasm fayli bo\'sh yoki yuklab bo\'lmadi.');
    }

    final base64Image = base64Encode(bytes);
    final mimeType = _resolveMimeType(imageFile.path);

    final provider = preferredProvider ?? await getActiveProvider();
    final groqKey = await getGroqApiKey();
    final geminiKey = await getGeminiApiKey();

    // If Groq selected or default, try Groq first
    if (provider == AiProvider.groq) {
      if (groqKey.isNotEmpty) {
        try {
          return await _scanWithGroq(
            apiKey: groqKey,
            base64Image: base64Image,
            mimeType: mimeType,
            focusMode: focusMode,
            extraInstructions: extraInstructions,
          );
        } catch (groqError) {
          debugPrint('Groq vision failed: $groqError');
          // If Gemini key is available, automatically try Gemini fallback
          if (geminiKey.isNotEmpty) {
            debugPrint('Attempting Gemini fallback...');
            return await _scanWithGemini(
              apiKey: geminiKey,
              base64Image: base64Image,
              mimeType: mimeType,
              focusMode: focusMode,
              extraInstructions: extraInstructions,
            );
          }
          rethrow;
        }
      } else if (geminiKey.isNotEmpty) {
        // Fallback to Gemini if only Gemini key is configured
        return await _scanWithGemini(
          apiKey: geminiKey,
          base64Image: base64Image,
          mimeType: mimeType,
          focusMode: focusMode,
          extraInstructions: extraInstructions,
        );
      } else {
        throw Exception(
          'Groq API kaliti topilmadi. Iltimos, sozlamalarda Groq API kalitingizni kiriting (console.groq.com/keys dan bepul olinadi).',
        );
      }
    } else {
      // User explicitly selected Gemini
      if (geminiKey.isNotEmpty) {
        return await _scanWithGemini(
          apiKey: geminiKey,
          base64Image: base64Image,
          mimeType: mimeType,
          focusMode: focusMode,
          extraInstructions: extraInstructions,
        );
      } else if (groqKey.isNotEmpty) {
        return await _scanWithGroq(
          apiKey: groqKey,
          base64Image: base64Image,
          mimeType: mimeType,
          focusMode: focusMode,
          extraInstructions: extraInstructions,
        );
      } else {
        throw Exception(
          'Gemini API kaliti topilmadi. Iltimos, sozlamalarda API kalitingizni kiriting.',
        );
      }
    }
  }

  /// Ultra-fast & smart multimodal vision via Groq LPU
  Future<AiScanResult> _scanWithGroq({
    required String apiKey,
    required String base64Image,
    required String mimeType,
    required ScanFocusMode focusMode,
    String? extraInstructions,
  }) async {
    final focusPrompt = _buildFocusPrompt(focusMode);
    final systemPrompt = '''
Siz ingliz tili va o'zbek tili bo'yicha kuchli, tajribali o'qituvchi hamda yuqori aniqlikdagi Optical Character Recognition (OCR) mutaxassisisiz.
$focusPrompt
${extraInstructions != null && extraInstructions.trim().isNotEmpty ? "Foydalanuvchi qo'shimcha ko'rsatmasi: $extraInstructions" : ""}

Rasmdagi har bir topilgan so'z uchun quyidagilarni aniqlang:
- word: so'zning o'zi (inglizcha boshlang'ich shaklda)
- translation: o'zbek tilidagi eng to'g'ri va tushunarli tarjimasi
- pronunciation: xalqaro fonetik transkripsiyasi (IPA, masalan: /ˌser.ənˈdɪp.ə.ti/)
- definition: inglizcha qisqa, aniq tushuntirish
- example: shu so'z ishlatilgan hayotiy va foydali inglizcha misol gap

Javobni FAQAT toza JSON formatida quyidagi strukturada qaytaring (hech qanday qo'shimcha matnsiz):
{
  "deck_name": "Rasmdagi mavzuga mos chiroyli o'zbekcha to'plam nomi",
  "words": [
    {
      "word": "resilience",
      "translation": "chidamlilik, matonat",
      "pronunciation": "/rɪˈzɪl.jəns/",
      "definition": "The capacity to recover quickly from difficulties",
      "example": "He showed great resilience during difficult times."
    }
  ]
}
''';

    final userInstruction =
        'Ushbu rasmni diqqat bilan o\'rganing va so\'zlarni ajratib, belgilangan JSON formatida qaytaring.';

    final imageUrl = 'data:$mimeType;base64,$base64Image';

    final requestPayload = {
      'model': defaultGroqVisionModel,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': userInstruction},
            {
              'type': 'image_url',
              'image_url': {'url': imageUrl},
            },
          ],
        },
      ],
      'temperature': 0.1,
      'response_format': {'type': 'json_object'},
    };

    http.Response? response;
    String? lastError;
    String usedModel = defaultGroqVisionModel;

    for (final model in fallbackGroqModels) {
      usedModel = model;
      requestPayload['model'] = model;

      try {
        final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
        response = await http
            .post(
              url,
              headers: {
                'Authorization': 'Bearer $apiKey',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(requestPayload),
            )
            .timeout(const Duration(seconds: 45));

        if (response.statusCode == 200) {
          break;
        } else {
          lastError = 'Groq (${response.statusCode}): ${response.body}';
        }
      } catch (e) {
        lastError = 'Groq xatosi: $e';
      }
    }

    if (response == null || response.statusCode != 200) {
      throw Exception(
        'Groq AI tahlilida xatolik: ${lastError ?? "Server javob bermadi"}',
      );
    }

    final resJson = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final choices = resJson['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('Groq AI javob qaytarmadi.');
    }

    final message = choices[0]['message'] as Map<String, dynamic>?;
    final rawText = (message?['content'] as String? ?? '').trim();
    if (rawText.isEmpty) {
      throw Exception('AI bo\'sh javob qaytardi.');
    }

    final parsedWords = _parseJsonResponse(rawText);
    return AiScanResult(
      suggestedDeckName: parsedWords.suggestedDeckName,
      words: parsedWords.words,
      providerName: 'Groq LPU AI',
      modelName: usedModel,
    );
  }

  /// Google Gemini Vision (Alternative / Fallback)
  Future<AiScanResult> _scanWithGemini({
    required String apiKey,
    required String base64Image,
    required String mimeType,
    required ScanFocusMode focusMode,
    String? extraInstructions,
  }) async {
    final focusPrompt = _buildFocusPrompt(focusMode);
    final prompt = '''
Siz ingliz tili va o'zbek tili bo'yicha tajribali o'qituvchisiz.
$focusPrompt
${extraInstructions != null && extraInstructions.trim().isNotEmpty ? "Foydalanuvchi qo'shimcha ko'rsatmasi: $extraInstructions" : ""}

Har bir topilgan so'z uchun quyidagilarni aniqlang:
- word: so'zning o'zi (inglizcha boshlang'ich shaklda)
- translation: o'zbek tilidagi aniq tarjimasi
- pronunciation: xalqaro fonetik transkripsiyasi (IPA)
- definition: inglizcha qisqa tushuntirish
- example: shu so'z ishlatilgan hayotiy va foydali inglizcha misol gap

Javobni FAQAT toza JSON formatida quyidagi strukturada qaytaring:
{
  "deck_name": "Tavsiya etilgan to'plam nomi",
  "words": [
    {
      "word": "example",
      "translation": "misol",
      "pronunciation": "/ɪɡˈzɑːm.pəl/",
      "definition": "A representative form or pattern",
      "example": "This is a good example of modern architecture."
    }
  ]
}
''';

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Image,
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.2,
        'response_mime_type': 'application/json',
      },
    });

    final models = ['gemini-2.0-flash', 'gemini-1.5-flash'];
    http.Response? response;
    String? lastError;
    String usedModel = models.first;

    for (final model in models) {
      usedModel = model;
      try {
        final url = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
        );
        response = await http
            .post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(const Duration(seconds: 40));

        if (response.statusCode == 200) {
          break;
        } else {
          lastError = 'Status ${response.statusCode}: ${response.body}';
        }
      } catch (e) {
        lastError = e.toString();
      }
    }

    if (response == null || response.statusCode != 200) {
      throw Exception(
        'Gemini AI bilan bog\'lanishda xatolik yuz berdi: ${lastError ?? 'Noma\'lum xatolik'}',
      );
    }

    final resJson = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final candidates = resJson['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('AI javob qaytarmadi.');
    }

    final content = candidates[0]['content'];
    final parts = content['parts'] as List;
    final rawText = (parts[0]['text'] as String).trim();

    final parsedWords = _parseJsonResponse(rawText);
    return AiScanResult(
      suggestedDeckName: parsedWords.suggestedDeckName,
      words: parsedWords.words,
      providerName: 'Gemini AI',
      modelName: usedModel,
    );
  }

  String _buildFocusPrompt(ScanFocusMode focusMode) {
    return switch (focusMode) {
      ScanFocusMode.highlighted =>
        'DIQQAT: Rasmda marker bilan belgilangan (highlight qilingan, masalan sariq, yashil, pushti ranglar bilan) yoki qalam/ruchka bilan tagiga chizilgan (underlined) notanish so\'z va iboralarga ustuvorlik bering. Faqat shunday belgilangan so\'zlarni toping va ajrating.',
      ScanFocusMode.vocabularyList =>
        'DIQQAT: Rasm lug\'at daftari yoki so\'zlar ro\'yxatidan iborat. Daftardagi har bir yozilgan yangi inglizcha so\'z va uning tarjimasini to\'liq o\'qib, lug\'at kartalariga aylantiring.',
      ScanFocusMode.allKeyWords =>
        'DIQQAT: Ushbu matndagi eng muhim, foydali va til o\'rganuvchilar uchun qiziq bo\'lgan yangi inglizcha so\'zlarni ajratib oling.',
    };
  }

  AiScanResult _parseJsonResponse(String rawText) {
    try {
      // 1. Remove thinking tokens if any (e.g. <think>...</think>)
      var cleaned = rawText.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '').trim();

      // 2. Remove markdown code fences
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      // 3. Extract JSON object bounds if there's text outside
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        cleaned = cleaned.substring(start, end + 1);
      }

      final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
      final deckName = (parsed['deck_name'] ??
              parsed['suggested_deck_name'] ??
              parsed['title'] ??
              'Rasmdan olingan so\'zlar')
          .toString()
          .trim();

      final wordsList = (parsed['words'] ??
          parsed['cards'] ??
          parsed['items'] ??
          parsed['vocabulary']) as List?;

      if (wordsList == null || wordsList.isEmpty) {
        throw Exception(
          'Rasmda ajratib olinadigan so\'zlar topilmadi. Iltimos, boshqa yoki aniqroq rasm yuklang.',
        );
      }

      final words = wordsList
          .map((w) => ExtractedWordItem.fromJson(Map<String, dynamic>.from(w as Map)))
          .where((w) => w.word.isNotEmpty && w.translation.isNotEmpty)
          .toList();

      if (words.isEmpty) {
        throw Exception(
          'Rasmda ajratib olinadigan so\'zlar topilmadi. Iltimos, aniqroq yoki belgilangan so\'zlar bor boshqa rasm yuklang.',
        );
      }

      return AiScanResult(suggestedDeckName: deckName, words: words);
    } catch (e) {
      debugPrint('JSON Parse Error: $e\nRaw Text: $rawText');
      if (e is Exception) rethrow;
      throw Exception('AI javobini tahlil qilishda xatolik: $e');
    }
  }

  String _resolveMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}
