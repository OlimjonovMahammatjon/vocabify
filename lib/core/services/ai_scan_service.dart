import 'dart:async';
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
    final rawPronunciation = json['pronunciation']?.toString().trim();
    final rawDefinition = json['definition']?.toString().trim();
    final rawExample =
        (json['example'] ?? json['example_sentence'])?.toString().trim();

    return ExtractedWordItem(
      word: (json['word'] ?? '').toString().trim(),
      translation: (json['translation'] ?? '').toString().trim(),
      pronunciation:
          rawPronunciation != null && rawPronunciation.isNotEmpty
              ? rawPronunciation
              : null,
      definition:
          rawDefinition != null && rawDefinition.isNotEmpty
              ? rawDefinition
              : null,
      example:
          rawExample != null && rawExample.isNotEmpty ? rawExample : null,
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
    this.modelName = AiScanService.defaultGroqVisionModel,
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

class _ModelResponse {
  final String text;
  final String modelName;

  const _ModelResponse({required this.text, required this.modelName});
}

class AiScanService {
  AiScanService._();
  static final AiScanService instance = AiScanService._();

  static const String _userGroqApiKeyPref = 'vocabify_user_groq_api_key';
  static const String _userGeminiApiKeyPref = 'vocabify_user_gemini_api_key';
  static const String _activeProviderPref = 'vocabify_active_ai_provider';

  // Vision models on Groq (primary + multimodal fallbacks)
  static const String defaultGroqVisionModel = 'qwen/qwen3.8-27b';
  static const List<String> fallbackGroqModels = [
    'qwen/qwen3.8-27b',
    'meta-llama/llama-4-maverick-17b-128e-instruct',
    'meta-llama/llama-4-scout-17b-16e-instruct',
    'meta-models/muse-spark-open',
  ];

  // Fast text models on Groq for single-word translation & example generation
  static const List<String> textGroqModels = [
    'llama-3.3-70b-versatile',
    'qwen/qwen3-32b',
    'qwen/qwen3.8-27b',
    'meta-llama/llama-4-scout-17b-16e-instruct',
  ];

  // Active Google Gemini models (v1beta)
  static const List<String> geminiModels = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
  ];

  /// Returns user-configured Groq key or AppConstants default.
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

  /// Returns user-configured Gemini key or AppConstants default.
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

  /// Generates Uzbek translation and a natural English example sentence for a word.
  Future<ExtractedWordItem> generateWordDetails({
    required String word,
    AiProvider? preferredProvider,
  }) async {
    final cleanWord = word.trim();
    if (cleanWord.isEmpty) {
      throw Exception('Avval so\'zni kiriting.');
    }

    final systemPrompt = '''
Siz ingliz tili va o'zbek tili bo'yicha tajribali leksikograf va o'qituvchisiz.
Foydalanuvchi kiritgan inglizcha so'z yoki ibora uchun aniq o'zbekcha tarjima va tabiiy inglizcha misol gap tuzing.

Javobni FAQAT toza JSON formatida qaytaring (boshqa hech qanday matnsiz):
{
  "word": "kiritilgan so'zning to'g'ri shakli",
  "translation": "o'zbek tilidagi eng aniq va tushunarli tarjimasi (1-3 ta mos ma'no)",
  "pronunciation": "/xalqaro fonetik transkripsiya/",
  "definition": "inglizcha qisqa izoh",
  "example": "Shu so'z ishlatilgan hayotiy, tabiiy va tushunarli inglizcha misol gap."
}
''';

    final userPrompt = 'So\'z yoki ibora: "$cleanWord"';

    return _executeWithProviderFallback<ExtractedWordItem>(
      preferredProvider: preferredProvider,
      runGroq: (apiKey) async {
        final res = await _postGroqChat(
          apiKey: apiKey,
          models: textGroqModels,
          messages: [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          temperature: 0.2,
          maxCompletionTokens: 512,
          timeout: const Duration(seconds: 25),
        );
        return parseWordDetailsJson(res.text, fallbackWord: cleanWord);
      },
      runGemini: (apiKey) async {
        final res = await _postGeminiGenerate(
          apiKey: apiKey,
          parts: [
            {'text': '$systemPrompt\n$userPrompt'},
          ],
          temperature: 0.2,
          timeout: const Duration(seconds: 25),
        );
        return parseWordDetailsJson(res.text, fallbackWord: cleanWord);
      },
    );
  }

  /// Scans image using Groq or Gemini with symmetric automatic fallback.
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

    return _executeWithProviderFallback<AiScanResult>(
      preferredProvider: preferredProvider,
      runGroq: (apiKey) => _scanWithGroq(
        apiKey: apiKey,
        base64Image: base64Image,
        mimeType: mimeType,
        focusMode: focusMode,
        extraInstructions: extraInstructions,
      ),
      runGemini: (apiKey) => _scanWithGemini(
        apiKey: apiKey,
        base64Image: base64Image,
        mimeType: mimeType,
        focusMode: focusMode,
        extraInstructions: extraInstructions,
      ),
    );
  }

  Future<T> _executeWithProviderFallback<T>({
    AiProvider? preferredProvider,
    required Future<T> Function(String apiKey) runGroq,
    required Future<T> Function(String apiKey) runGemini,
  }) async {
    final provider = preferredProvider ?? await getActiveProvider();
    final groqKey = await getGroqApiKey();
    final geminiKey = await getGeminiApiKey();

    if (groqKey.isEmpty && geminiKey.isEmpty) {
      throw Exception(
        'AI API kaliti topilmadi. Iltimos, sozlamalarda Groq yoki Gemini API kalitingizni kiriting.',
      );
    }

    final primaryIsGroq = provider == AiProvider.groq;
    final primaryKey = primaryIsGroq ? groqKey : geminiKey;
    final secondaryKey = primaryIsGroq ? geminiKey : groqKey;
    final runPrimary = primaryIsGroq ? runGroq : runGemini;
    final runSecondary = primaryIsGroq ? runGemini : runGroq;

    if (primaryKey.isNotEmpty) {
      try {
        return await runPrimary(primaryKey);
      } catch (primaryError) {
        debugPrint('Primary AI provider failed: $primaryError');
        if (secondaryKey.isNotEmpty) {
          debugPrint('Attempting fallback AI provider...');
          try {
            return await runSecondary(secondaryKey);
          } catch (secondaryError) {
            debugPrint('Fallback AI provider failed: $secondaryError');
            rethrow;
          }
        }
        rethrow;
      }
    }

    return await runSecondary(secondaryKey);
  }

  String _buildVisionPrompt({
    required ScanFocusMode focusMode,
    String? extraInstructions,
  }) {
    final focusPrompt = _buildFocusPrompt(focusMode);
    final extra =
        extraInstructions != null && extraInstructions.trim().isNotEmpty
            ? "\nFoydalanuvchi qo'shimcha ko'rsatmasi: ${extraInstructions.trim()}"
            : '';

    return '''
Siz ingliz tili va o'zbek tili bo'yicha kuchli, tajribali o'qituvchi hamda yuqori aniqlikdagi Optical Character Recognition (OCR) mutaxassisisiz.
$focusPrompt$extra

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
  }

  /// Ultra-fast & smart multimodal vision via Groq LPU.
  Future<AiScanResult> _scanWithGroq({
    required String apiKey,
    required String base64Image,
    required String mimeType,
    required ScanFocusMode focusMode,
    String? extraInstructions,
  }) async {
    final systemPrompt = _buildVisionPrompt(
      focusMode: focusMode,
      extraInstructions: extraInstructions,
    );
    const userInstruction =
        'Ushbu rasmni diqqat bilan o\'rganing va so\'zlarni ajratib, belgilangan JSON formatida qaytaring.';
    final imageUrl = 'data:$mimeType;base64,$base64Image';

    final res = await _postGroqChat(
      apiKey: apiKey,
      models: fallbackGroqModels,
      messages: [
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
      temperature: 0.1,
      maxCompletionTokens: 4096,
      timeout: const Duration(seconds: 45),
    );

    final parsedWords = parseScanJsonResponse(res.text);
    return AiScanResult(
      suggestedDeckName: parsedWords.suggestedDeckName,
      words: parsedWords.words,
      providerName: 'Groq LPU AI',
      modelName: res.modelName,
    );
  }

  /// Google Gemini Vision (Alternative / Fallback).
  Future<AiScanResult> _scanWithGemini({
    required String apiKey,
    required String base64Image,
    required String mimeType,
    required ScanFocusMode focusMode,
    String? extraInstructions,
  }) async {
    final prompt = _buildVisionPrompt(
      focusMode: focusMode,
      extraInstructions: extraInstructions,
    );

    final res = await _postGeminiGenerate(
      apiKey: apiKey,
      parts: [
        {'text': prompt},
        {
          'inline_data': {
            'mime_type': mimeType,
            'data': base64Image,
          },
        },
      ],
      temperature: 0.2,
      timeout: const Duration(seconds: 45),
    );

    final parsedWords = parseScanJsonResponse(res.text);
    return AiScanResult(
      suggestedDeckName: parsedWords.suggestedDeckName,
      words: parsedWords.words,
      providerName: 'Gemini AI',
      modelName: res.modelName,
    );
  }

  Future<_ModelResponse> _postGroqChat({
    required String apiKey,
    required List<String> models,
    required List<Map<String, dynamic>> messages,
    required double temperature,
    required int maxCompletionTokens,
    required Duration timeout,
  }) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    String? lastError;

    for (final model in models) {
      for (final useJsonMode in [true, false]) {
        final payload = <String, dynamic>{
          'model': model,
          'messages': messages,
          'temperature': temperature,
          'max_completion_tokens': maxCompletionTokens,
          if (useJsonMode) 'response_format': {'type': 'json_object'},
        };

        try {
          final response = await http
              .post(
                url,
                headers: {
                  'Authorization': 'Bearer $apiKey',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode(payload),
              )
              .timeout(timeout);

          if (response.statusCode == 200) {
            final resJson =
                jsonDecode(utf8.decode(response.bodyBytes))
                    as Map<String, dynamic>;
            final choices = resJson['choices'] as List?;
            if (choices == null || choices.isEmpty) {
              lastError = 'Groq AI ($model) bo\'sh javob qaytardi.';
              break;
            }
            final message = choices[0]['message'] as Map<String, dynamic>?;
            final rawText = (message?['content'] as String? ?? '').trim();
            if (rawText.isEmpty) {
              lastError = 'Groq AI ($model) bo\'sh matn qaytardi.';
              break;
            }
            return _ModelResponse(text: rawText, modelName: model);
          }

          if (response.statusCode == 401 || response.statusCode == 403) {
            throw Exception(
              'Groq API kaliti noto\'g\'ri yoki faol emas. Iltimos, sozlamalarda kalitni tekshiring.',
            );
          }

          if (response.statusCode == 413) {
            throw Exception(
              'Rasm hajmi Groq chegarasidan katta. Kichikroq yoki kesilgan rasm tanlang.',
            );
          }

          final bodyText = utf8.decode(response.bodyBytes, allowMalformed: true);
          lastError = _extractApiErrorMessage(
            statusCode: response.statusCode,
            body: bodyText,
            providerLabel: 'Groq',
          );

          // Retry same model without strict json_object if the model/request rejects it.
          if (useJsonMode &&
              response.statusCode == 400 &&
              (bodyText.contains('json_validate_failed') ||
                  bodyText.contains('response_format'))) {
            continue;
          }

          break;
        } on TimeoutException {
          lastError = 'Groq serveri ($model) belgilangan vaqtda javob bermadi.';
          break;
        } on SocketException {
          throw Exception('Internet aloqasini tekshiring.');
        } catch (e) {
          if (e is Exception &&
              (e.toString().contains('API kaliti') ||
                  e.toString().contains('Rasm hajmi') ||
                  e.toString().contains('Internet aloqasini'))) {
            rethrow;
          }
          lastError = 'Groq xatosi ($model): $e';
          break;
        }
      }
    }

    throw Exception(lastError ?? 'Groq AI bilan bog\'lanib bo\'lmadi.');
  }

  Future<_ModelResponse> _postGeminiGenerate({
    required String apiKey,
    required List<Map<String, dynamic>> parts,
    required double temperature,
    required Duration timeout,
  }) async {
    String? lastError;

    for (final model in geminiModels) {
      for (final useJsonMime in [true, false]) {
        final payload = <String, dynamic>{
          'contents': [
            {'parts': parts},
          ],
          'generationConfig': {
            'temperature': temperature,
            if (useJsonMime) 'response_mime_type': 'application/json',
          },
        };

        try {
          final url = Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
          );
          final response = await http
              .post(
                url,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(payload),
              )
              .timeout(timeout);

          if (response.statusCode == 200) {
            final resJson =
                jsonDecode(utf8.decode(response.bodyBytes))
                    as Map<String, dynamic>;
            final text = extractGeminiText(resJson);
            if (text.isEmpty) {
              lastError = 'Gemini AI ($model) bo\'sh javob qaytardi.';
              break;
            }
            return _ModelResponse(text: text, modelName: model);
          }

          final bodyText = utf8.decode(response.bodyBytes, allowMalformed: true);
          if (response.statusCode == 401 ||
              response.statusCode == 403 ||
              bodyText.contains('API_KEY_INVALID')) {
            throw Exception(
              'Gemini API kaliti noto\'g\'ri yoki faol emas. Iltimos, sozlamalarda kalitni tekshiring.',
            );
          }

          lastError = _extractApiErrorMessage(
            statusCode: response.statusCode,
            body: bodyText,
            providerLabel: 'Gemini',
          );

          if (useJsonMime &&
              response.statusCode == 400 &&
              bodyText.contains('response_mime_type')) {
            continue;
          }

          break;
        } on TimeoutException {
          lastError = 'Gemini serveri ($model) belgilangan vaqtda javob bermadi.';
          break;
        } on SocketException {
          throw Exception('Internet aloqasini tekshiring.');
        } catch (e) {
          if (e is Exception &&
              (e.toString().contains('API kaliti') ||
                  e.toString().contains('Internet aloqasini'))) {
            rethrow;
          }
          lastError = 'Gemini xatosi ($model): $e';
          break;
        }
      }
    }

    throw Exception(lastError ?? 'Gemini AI bilan bog\'lanib bo\'lmadi.');
  }

  /// Extracts non-thought text parts from a Gemini response payload.
  @visibleForTesting
  static String extractGeminiText(Map<String, dynamic> resJson) {
    final candidates = resJson['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return '';

    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List?;
    if (parts == null || parts.isEmpty) return '';

    final nonThoughtTexts = <String>[];
    for (final part in parts) {
      if (part is! Map) continue;
      if (part['thought'] == true) continue;
      final text = part['text']?.toString().trim();
      if (text != null && text.isNotEmpty) {
        nonThoughtTexts.add(text);
      }
    }
    return nonThoughtTexts.join('\n').trim();
  }

  String _extractApiErrorMessage({
    required int statusCode,
    required String body,
    required String providerLabel,
  }) {
    if (statusCode == 429) {
      return '$providerLabel so\'rovlar limiti tugadi (429). Biroz kutib qayta urinib ko\'ring.';
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        final msg = decoded['error']['message']?.toString().trim();
        if (msg != null && msg.isNotEmpty) {
          return '$providerLabel xatosi ($statusCode): $msg';
        }
      }
    } catch (_) {}
    return '$providerLabel xatosi ($statusCode)';
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

  static String _stripThinkingAndFences(String rawText) {
    var cleaned = rawText
        .replaceAll(RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false), '')
        .trim();

    // Handle truncated or unclosed <think> tag if JSON follows or precedes it
    if (cleaned.toLowerCase().contains('<think>')) {
      final thinkIdx = cleaned.toLowerCase().indexOf('<think>');
      final jsonStart = cleaned.indexOf('{');
      final arrStart = cleaned.indexOf('[');
      final firstJson = [jsonStart, arrStart].where((i) => i != -1).fold<int>(
        -1,
        (prev, curr) => prev == -1 || curr < prev ? curr : prev,
      );
      if (firstJson > thinkIdx) {
        cleaned = cleaned.substring(firstJson).trim();
      }
    }

    cleaned = cleaned.replaceAll(RegExp(r'```json\s*', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'```\s*'), '').trim();
    return cleaned;
  }

  static dynamic _decodeLooseJson(String rawText) {
    var cleaned = _stripThinkingAndFences(rawText);

    final objStart = cleaned.indexOf('{');
    final objEnd = cleaned.lastIndexOf('}');
    final arrStart = cleaned.indexOf('[');
    final arrEnd = cleaned.lastIndexOf(']');

    final hasObj = objStart != -1 && objEnd > objStart;
    final hasArr = arrStart != -1 && arrEnd > arrStart;

    if (hasArr && (!hasObj || arrStart < objStart)) {
      cleaned = cleaned.substring(arrStart, arrEnd + 1);
    } else if (hasObj) {
      cleaned = cleaned.substring(objStart, objEnd + 1);
    }

    return jsonDecode(cleaned);
  }

  @visibleForTesting
  static ExtractedWordItem parseWordDetailsJson(
    String rawText, {
    required String fallbackWord,
  }) {
    try {
      final decoded = _decodeLooseJson(rawText);
      Map<String, dynamic>? map;
      if (decoded is Map) {
        if (decoded['words'] is List && (decoded['words'] as List).isNotEmpty) {
          map = Map<String, dynamic>.from((decoded['words'] as List).first as Map);
        } else {
          map = Map<String, dynamic>.from(decoded);
        }
      } else if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
        map = Map<String, dynamic>.from(decoded.first as Map);
      }

      if (map == null) {
        throw Exception('AI javobi kutilgan formatda emas.');
      }

      final item = ExtractedWordItem.fromJson(map);
      if (item.word.isEmpty) {
        item.word = fallbackWord;
      }
      if (item.translation.isEmpty) {
        throw Exception('AI tarjima qaytarmadi. Qayta urinib ko\'ring.');
      }
      return item;
    } catch (e) {
      debugPrint('Word Details JSON Parse Error: $e\nRaw Text: $rawText');
      if (e is Exception) rethrow;
      throw Exception('AI javobini tahlil qilishda xatolik: $e');
    }
  }

  @visibleForTesting
  static AiScanResult parseScanJsonResponse(String rawText) {
    try {
      final decoded = _decodeLooseJson(rawText);

      String deckName = 'Rasmdan olingan so\'zlar';
      List? wordsList;

      if (decoded is List) {
        wordsList = decoded;
      } else if (decoded is Map) {
        final parsed = Map<String, dynamic>.from(decoded);
        final rawDeckName = (parsed['deck_name'] ??
                parsed['suggested_deck_name'] ??
                parsed['title'])
            ?.toString()
            .trim();
        if (rawDeckName != null && rawDeckName.isNotEmpty) {
          deckName = rawDeckName;
        }
        wordsList = (parsed['words'] ??
            parsed['cards'] ??
            parsed['items'] ??
            parsed['vocabulary']) as List?;
      }

      if (wordsList == null || wordsList.isEmpty) {
        throw Exception(
          'Rasmda ajratib olinadigan so\'zlar topilmadi. Iltimos, boshqa yoki aniqroq rasm yuklang.',
        );
      }

      final words = wordsList
          .whereType<Map>()
          .map((w) => ExtractedWordItem.fromJson(Map<String, dynamic>.from(w)))
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
