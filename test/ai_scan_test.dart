import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocabify_app/core/services/ai_scan_service.dart';
import 'package:vocabify_app/screens/decks/card_form_screen.dart';

void main() {
  group('AiScanService Models & Parsing Tests', () {
    test('ExtractedWordItem deserialization from JSON', () {
      final json = {
        'word': '  Ephemeral  ',
        'translation': '  Vaqtinchalik, tez o\'tuvchi  ',
        'pronunciation': '/ɪˈfem.ər.əl/',
        'definition': 'Lasting for a very short time.',
        'example': 'Fashions are ephemeral.',
      };

      final item = ExtractedWordItem.fromJson(json);

      expect(item.word, 'Ephemeral');
      expect(item.translation, 'Vaqtinchalik, tez o\'tuvchi');
      expect(item.pronunciation, '/ɪˈfem.ər.əl/');
      expect(item.definition, 'Lasting for a very short time.');
      expect(item.example, 'Fashions are ephemeral.');
      expect(item.isSelected, true);
    });

    test('ExtractedWordItem handles null and missing optional fields', () {
      final json = {
        'word': 'Serendipity',
        'translation': 'Tasodifiy baxtli topilma',
      };

      final item = ExtractedWordItem.fromJson(json);

      expect(item.word, 'Serendipity');
      expect(item.translation, 'Tasodifiy baxtli topilma');
      expect(item.pronunciation, null);
      expect(item.definition, null);
      expect(item.example, null);
      expect(item.isSelected, true);
    });

    test('ExtractedWordItem serialization to JSON', () {
      final item = ExtractedWordItem(
        word: 'Tenacious',
        translation: 'Qat\'iyatli',
        pronunciation: '/təˈneɪ.ʃəs/',
        definition: 'Not readily letting go of or giving up something.',
        example: 'A tenacious student.',
      );

      final map = item.toJson();

      expect(map['word'], 'Tenacious');
      expect(map['translation'], 'Qat\'iyatli');
      expect(map['pronunciation'], '/təˈneɪ.ʃəs/');
      expect(map['definition'], 'Not readily letting go of or giving up something.');
      expect(map['example'], 'A tenacious student.');
    });

    test('AiScanResult holds deck name, words list, and Groq metadata', () {
      final words = [
        ExtractedWordItem(word: 'Eloquent', translation: 'Fasohotli'),
        ExtractedWordItem(word: 'Meticulous', translation: 'Mayda-chuyasigacha e\'tiborli'),
      ];

      final result = AiScanResult(
        suggestedDeckName: 'Unit 5 Vocabulary',
        words: words,
        providerName: 'Groq LPU AI',
        modelName: 'qwen/qwen3.8-27b',
      );

      expect(result.suggestedDeckName, 'Unit 5 Vocabulary');
      expect(result.words.length, 2);
      expect(result.words[0].word, 'Eloquent');
      expect(result.words[1].word, 'Meticulous');
      expect(result.providerName, 'Groq LPU AI');
      expect(result.modelName, 'qwen/qwen3.8-27b');
    });

    test('ScanFocusMode enum values exist', () {
      expect(ScanFocusMode.values.length, 3);
      expect(ScanFocusMode.values.contains(ScanFocusMode.highlighted), true);
      expect(ScanFocusMode.values.contains(ScanFocusMode.vocabularyList), true);
      expect(ScanFocusMode.values.contains(ScanFocusMode.allKeyWords), true);
    });

    test('AiProvider enum includes Groq as primary', () {
      expect(AiProvider.values.contains(AiProvider.groq), true);
      expect(AiProvider.values.contains(AiProvider.gemini), true);
      expect(AiScanService.defaultGroqVisionModel, 'qwen/qwen3.8-27b');
      expect(
        AiScanService.fallbackGroqModels,
        contains('meta-llama/llama-4-scout-17b-16e-instruct'),
      );
      expect(AiScanService.textGroqModels, contains('llama-3.3-70b-versatile'));
      expect(AiScanService.geminiModels, ['gemini-2.5-flash', 'gemini-2.0-flash']);
    });

    test('parseWordDetailsJson handles thinking tags and markdown fences', () {
      const raw = '''
<think>Thinking about the word resilience...</think>
```json
{
  "word": "resilience",
  "translation": "chidamlilik, matonat",
  "pronunciation": "/rɪˈzɪl.jəns/",
  "definition": "The capacity to recover quickly",
  "example": "She showed remarkable resilience."
}
```
''';
      final item = AiScanService.parseWordDetailsJson(
        raw,
        fallbackWord: 'resilience',
      );
      expect(item.word, 'resilience');
      expect(item.translation, 'chidamlilik, matonat');
      expect(item.example, 'She showed remarkable resilience.');
    });

    test('parseScanJsonResponse supports top-level JSON array', () {
      const raw = '''
```json
[
  {
    "word": "lucid",
    "translation": "ravshan, tushunarli",
    "example": "His explanation was lucid."
  }
]
```
''';
      final result = AiScanService.parseScanJsonResponse(raw);
      expect(result.words.length, 1);
      expect(result.words.first.word, 'lucid');
      expect(result.words.first.translation, 'ravshan, tushunarli');
    });

    test('extractGeminiText skips thought parts from thinking models', () {
      final payload = {
        'candidates': [
          {
            'content': {
              'parts': [
                {'thought': true, 'text': 'internal reasoning'},
                {'text': '{"word":"vivid","translation":"yorqin"}'},
              ],
            },
          },
        ],
      };

      expect(
        AiScanService.extractGeminiText(payload),
        '{"word":"vivid","translation":"yorqin"}',
      );
    });

    testWidgets('CardFormModal shows AI fill buttons and validates empty word', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: CardFormModal(deckId: 'deck-1')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI to\'ldirish'), findsOneWidget);
      expect(find.text('AI misol'), findsOneWidget);

      await tester.tap(find.text('AI to\'ldirish'));
      await tester.pump();
      expect(find.text('Avval inglizcha so\'zni kiriting'), findsOneWidget);
    });
  });
}
