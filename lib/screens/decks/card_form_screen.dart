import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/ai_scan_service.dart';
import '../../models/card_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cards_provider.dart';
import '../../providers/decks_provider.dart';
import '../../widgets/ai_settings_dialog.dart';

/// Shows the "Yangi so'z qo'shish" modal bottom sheet matching the exact design.
Future<void> showAddWordModal(
  BuildContext context, {
  required String deckId,
  CardModel? card,
  int initialTab = 0,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (ctx) =>
        CardFormModal(deckId: deckId, card: card, initialTab: initialTab),
  );
}

/// Custom painter for dashed rounded border button
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashPattern;
  final double gapPattern;
  final double radius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.2,
    this.dashPattern = 5.0,
    this.gapPattern = 4.0,
    this.radius = 14.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double start = 0;
      while (start < metric.length) {
        final end = (start + dashPattern).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(start, end), paint);
        start += dashPattern + gapPattern;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius;
  }
}

class CardFormModal extends StatefulWidget {
  final String deckId;
  final CardModel? card;
  final int initialTab;

  const CardFormModal({
    super.key,
    required this.deckId,
    this.card,
    this.initialTab = 0,
  });

  @override
  State<CardFormModal> createState() => _CardFormModalState();
}

class _CardFormModalState extends State<CardFormModal> {
  late int _selectedTab; // 0: Yangi so'z, 1: JSON import

  // Single word controllers
  final _formKey = GlobalKey<FormState>();
  final _wordController = TextEditingController();
  final _translationController = TextEditingController();
  final _exampleController = TextEditingController();
  bool _isSubmitting = false;
  bool _isGeneratingAi = false;

  // JSON import controllers
  final _jsonController = TextEditingController();
  bool _isImporting = false;

  static const String _sampleJson = '''[
  {
    "word": "serendipity",
    "translation": "tasodifiy yaxshi narsa topish",
    "example": "Meeting her was pure serendipity."
  }
]''';

  static const String _aiPromptTemplate = '''Quyidagi so'zlarni berilgan JSON formatiga o'tkazib ber. Har bir so'z uchun inglizcha so'z (word), o'zbekcha tarjimasi (translation) va inglizcha misol gap (example) bo'lsin. Faqat toza JSON formatida javob qaytar (boshqa hech qanday izoh yoki belgilarsiz):

[
  {
    "word": "serendipity",
    "translation": "tasodifiy yaxshi narsa topish",
    "example": "Meeting her was pure serendipity."
  }
]

So'zlar ro'yxati:
''';

  void _showPromptDialog(BuildContext context, bool isDark) {
    Clipboard.setData(const ClipboardData(text: _aiPromptTemplate));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFF2563EB),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'AI uchun prompt',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prompt nusxalandi! 📋\nUni ChatGPT, Claude yoki Gemini\'ga yuborib, so\'zlaringizni tayyor JSON holida olishingiz mumkin:',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: SelectableText(
                _aiPromptTemplate,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  height: 1.35,
                  color: isDark
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Yopish',
              style: TextStyle(
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: _aiPromptTemplate));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Prompt buferga nusxalandi! 📋'),
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Color(0xFF1E293B),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Qayta nusxalash'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.card != null ? 0 : widget.initialTab;
    if (widget.card != null) {
      _wordController.text = widget.card!.word;
      _translationController.text = widget.card!.translation;
      _exampleController.text = widget.card!.exampleSentence ?? '';
    }
  }

  @override
  void dispose() {
    _wordController.dispose();
    _translationController.dispose();
    _exampleController.dispose();
    _jsonController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _cleanAndParseJson(String rawText) {
    var text = rawText.trim();
    if (text.isEmpty) return [];

    // Strip markdown fences
    text = text.replaceAll(RegExp(r'```json\s*', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'```\s*'), '');

    final startBracket = text.indexOf('[');
    final endBracket = text.lastIndexOf(']');
    if (startBracket != -1 && endBracket != -1 && endBracket > startBracket) {
      text = text.substring(startBracket, endBracket + 1);
    } else {
      final startBrace = text.indexOf('{');
      final endBrace = text.lastIndexOf('}');
      if (startBrace != -1 && endBrace != -1 && endBrace > startBrace) {
        text = text.substring(startBrace, endBrace + 1);
      }
    }

    try {
      final parsed = jsonDecode(text);
      if (parsed is List) {
        return parsed
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (parsed is Map) {
        return [Map<String, dynamic>.from(parsed)];
      }
    } catch (_) {}
    return [];
  }

  Future<void> _pickFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (files.isNotEmpty && files.first.path != null) {
        final file = File(files.first.path!);
        final content = await file.readAsString();
        if (!mounted) return;
        setState(() {
          _jsonController.text = content;
        });
      }
    } catch (e) {
      debugPrint('File picker error: $e');
    }
  }

  Future<void> _generateWithAi({bool onlyExample = false}) async {
    final word = _wordController.text.trim();
    if (word.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Avval inglizcha so\'zni kiriting'),
            backgroundColor: AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    final hasKey = await AiScanService.instance.hasAnyApiKey();
    if (!mounted) return;
    if (!hasKey) {
      final saved = await showAiSettingsDialog(context);
      if (saved != true || !mounted) return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isGeneratingAi = true);

    try {
      final item = await AiScanService.instance.generateWordDetails(word: word);
      if (!mounted) return;

      setState(() {
        if (!onlyExample || _translationController.text.trim().isEmpty) {
          _translationController.text = item.translation;
        }
        if ((item.example ?? '').trim().isNotEmpty) {
          _exampleController.text = item.example!.trim();
        }
      });

      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              onlyExample
                  ? 'AI misol gap yaratdi ✨'
                  : 'Tarjima va misol gap AI bilan to\'ldirildi ✨',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception:', '').trim();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.destructive,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Sozlamalar',
              textColor: Colors.white,
              onPressed: () {
                showAiSettingsDialog(context, showSavedSnackBar: true);
              },
            ),
          ),
        );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingAi = false);
      }
    }
  }

  Future<void> _handleSaveSingle() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final auth = context.read<AuthProvider>();
    final cardsProv = context.read<CardsProvider>();
    final decksProv = context.read<DecksProvider>();

    final word = _wordController.text.trim();
    final translation = _translationController.text.trim();
    final example = _exampleController.text.trim();

    if (widget.card != null) {
      await cardsProv.updateCard(
        cardId: widget.card!.id,
        deckId: widget.deckId,
        word: word,
        translation: translation,
        exampleSentence: example,
      );
    } else {
      final userId = auth.user?.id;
      if (userId != null) {
        await cardsProv.addCard(
          userId: userId,
          deckId: widget.deckId,
          word: word,
          translation: translation,
          exampleSentence: example,
        );
        decksProv.updateCardCount(widget.deckId, 1);
      }
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.card != null ? 'Yangilandi' : 'So\'z qo\'shildi 🎉',
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _handleBulkImport() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;

    final items = _cleanAndParseJson(_jsonController.text);
    final validItems = items
        .where(
          (e) =>
              e['word']?.toString().trim().isNotEmpty == true &&
              e['translation']?.toString().trim().isNotEmpty == true,
        )
        .toList();

    if (validItems.isEmpty) return;

    setState(() => _isImporting = true);
    final cardsProv = context.read<CardsProvider>();
    final decksProv = context.read<DecksProvider>();

    try {
      final count = await cardsProv.bulkImportCards(
        userId: userId,
        deckId: widget.deckId,
        items: validItems,
      );
      decksProv.updateCardCount(widget.deckId, count);

      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count ta so\'z muvaffaqiyatli import qilindi! 🎉'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import qilishda xatolik: $e'),
            backgroundColor: AppColors.destructive,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parsedItems = _cleanAndParseJson(_jsonController.text);
    final validItems = parsedItems
        .where(
          (e) =>
              e['word']?.toString().trim().isNotEmpty == true &&
              e['translation']?.toString().trim().isNotEmpty == true,
        )
        .toList();

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        width: 1.2,
      ),
    );
    final focusedInputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
        width: 1.6,
      ),
    );
    final fieldFillColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFF8FAFC);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF151C28) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row: Centered Title + Close Button
              Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    widget.card != null
                        ? 'So\'zni tahrirlash'
                        : 'Yangi so\'z qo\'shish',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Segmented Toggle Tabs (only if adding new word)
              if (widget.card == null) ...[
                _buildSegmentedToggle(isDark),
                const SizedBox(height: 20),
              ],

              // Content based on tab
              if (_selectedTab == 0)
                _buildSingleWordTab(
                  isDark,
                  inputBorder,
                  focusedInputBorder,
                  fieldFillColor,
                )
              else
                _buildJsonImportTab(
                  isDark,
                  inputBorder,
                  focusedInputBorder,
                  fieldFillColor,
                  parsedItems,
                  validItems,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Segmented Pill Control: [ Yangi so'z ] [ JSON import ]
  Widget _buildSegmentedToggle(bool isDark) {
    final bgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final activeColor = isDark ? const Color(0xFF28364F) : Colors.white;
    final activeTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final inactiveTextColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedTab == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'Yangi so\'z',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: _selectedTab == 0
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: _selectedTab == 0
                        ? activeTextColor
                        : inactiveTextColor,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? activeColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _selectedTab == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'JSON import',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: _selectedTab == 1
                        ? FontWeight.w600
                        : FontWeight.w500,
                    color: _selectedTab == 1
                        ? activeTextColor
                        : inactiveTextColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // TAB 1: Single Word Form
  Widget _buildSingleWordTab(
    bool isDark,
    OutlineInputBorder inputBorder,
    OutlineInputBorder focusedInputBorder,
    Color fieldFillColor,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. So'z (English) * + AI Auto-fill button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'So\'z (English) *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              _AiFillButton(
                label: 'AI to\'ldirish',
                isLoading: _isGeneratingAi,
                isDark: isDark,
                onTap: _isGeneratingAi ? null : () => _generateWithAi(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _wordController,
            autofocus: false,
            style: const TextStyle(fontSize: 14.5),
            decoration: InputDecoration(
              hintText: 'serendipity',
              hintStyle: TextStyle(
                color: isDark
                    ? const Color(0xFF64748B)
                    : const Color(0xFF94A3B8),
                fontSize: 14,
              ),
              filled: true,
              fillColor: fieldFillColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: inputBorder,
              enabledBorder: inputBorder,
              focusedBorder: focusedInputBorder,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'So\'z kiriting';
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // 2. O'zbekcha tarjima *
          Text(
            'O\'zbekcha tarjima *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _translationController,
            style: const TextStyle(fontSize: 14.5),
            decoration: InputDecoration(
              hintText: 'tasodifiy yaxshi narsa topish',
              hintStyle: TextStyle(
                color: isDark
                    ? const Color(0xFF64748B)
                    : const Color(0xFF94A3B8),
                fontSize: 14,
              ),
              filled: true,
              fillColor: fieldFillColor,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: inputBorder,
              enabledBorder: inputBorder,
              focusedBorder: focusedInputBorder,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Tarjimani kiriting';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // 3. Misol gap + AI example button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Misol gap',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              _AiFillButton(
                label: 'AI misol',
                isLoading: _isGeneratingAi,
                isDark: isDark,
                compact: true,
                onTap: _isGeneratingAi
                    ? null
                    : () => _generateWithAi(onlyExample: true),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _exampleController,
            minLines: 3,
            maxLines: 4,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Meeting her was pure serendipity.',
              hintStyle: TextStyle(
                color: isDark
                    ? const Color(0xFF64748B)
                    : const Color(0xFF94A3B8),
                fontSize: 14,
              ),
              filled: true,
              fillColor: fieldFillColor,
              contentPadding: const EdgeInsets.all(14),
              border: inputBorder,
              enabledBorder: inputBorder,
              focusedBorder: focusedInputBorder,
            ),
          ),
          const SizedBox(height: 24),

          // 4. Qo'shish Button
          ElevatedButton(
            onPressed: _isSubmitting ? null : _handleSaveSingle,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    widget.card != null ? 'Saqlash' : 'Qo\'shish',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // TAB 2: JSON Import Form
  Widget _buildJsonImportTab(
    bool isDark,
    OutlineInputBorder inputBorder,
    OutlineInputBorder focusedInputBorder,
    Color fieldFillColor,
    List<Map<String, dynamic>> parsedItems,
    List<Map<String, dynamic>> validItems,
  ) {
    final validCount = validItems.length;
    final totalCount = parsedItems.isNotEmpty ? parsedItems.length : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Row: "JSON ma'lumot" + "Promptni olish"
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'JSON ma\'lumot',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            GestureDetector(
              onTap: () => _showPromptDialog(context, isDark),
              child: const Text(
                'Promptni olish',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF2563EB),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // JSON Text Area
        TextFormField(
          controller: _jsonController,
          minLines: 5,
          maxLines: 7,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12.5,
            height: 1.45,
          ),
          decoration: InputDecoration(
            hintText: _sampleJson,
            hintStyle: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            ),
            filled: true,
            fillColor: fieldFillColor,
            contentPadding: const EdgeInsets.all(14),
            border: inputBorder,
            enabledBorder: inputBorder,
            focusedBorder: focusedInputBorder,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),

        // Dashed Border Button: .json fayl yuklash
        CustomPaint(
          painter: DashedBorderPainter(
            color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
            strokeWidth: 1.2,
            radius: 14,
          ),
          child: InkWell(
            onTap: _pickFile,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.file_upload_outlined,
                    size: 20,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '.json fayl yuklash',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Validation & Preview Box (shown when user entered text)
        if (_jsonController.text.trim().isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B2433) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row: Checkmark + count
                Row(
                  children: [
                    Icon(
                      validCount > 0
                          ? Icons.check_circle_outline_rounded
                          : Icons.error_outline_rounded,
                      color: validCount > 0
                          ? const Color(0xFF10B981)
                          : AppColors.destructive,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$validCount / $totalCount ta so\'z yaroqli',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: validCount > 0
                            ? (isDark ? Colors.white : const Color(0xFF0F172A))
                            : AppColors.destructive,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Row: Eye icon + "Ko'rib chiqish"
                Row(
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      size: 15,
                      color: isDark ? Colors.white54 : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ko\'rib chiqish',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Card Preview Items - exactly matches screenshot (word bold + translation)
                if (validItems.isNotEmpty)
                  ...validItems.take(4).map((item) {
                    final w = item['word']?.toString() ?? '';
                    final t = item['translation']?.toString() ?? '';

                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF151C28) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFEDF2F7),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            w,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            t,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white60
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    );
                  })
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Yaroqli so\'zlar topilmadi. JSON ni tekshiring.',
                      style: TextStyle(
                        color: AppColors.destructive,
                        fontSize: 12.5,
                      ),
                    ),
                  ),

                if (validItems.length > 4)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '+ yana ${validItems.length - 4} ta so\'z import qilinadi',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Submit Button: [📄] X ta so'zni import qilish
        ElevatedButton.icon(
          onPressed: (validCount == 0 || _isImporting)
              ? null
              : _handleBulkImport,
          icon: _isImporting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.integration_instructions_outlined, size: 18),
          label: Text(
            _isImporting
                ? 'Import qilinmoqda...'
                : '$validCount ta so\'zni import qilish',
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E293B),
            foregroundColor: Colors.white,
            disabledBackgroundColor: isDark
                ? const Color(0xFF1E293B).withValues(alpha: 0.4)
                : const Color(0xFFE2E8F0),
            disabledForegroundColor: isDark
                ? Colors.white38
                : const Color(0xFF94A3B8),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }
}

class _AiFillButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final bool isDark;
  final bool compact;
  final VoidCallback? onTap;

  const _AiFillButton({
    required this.label,
    required this.isLoading,
    required this.isDark,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? AppColors.brand.withValues(alpha: 0.16)
        : const Color(0xFFEFF6FF);
    final borderColor = AppColors.brand.withValues(alpha: 0.35);
    final fgColor = isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB);

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 4 : 5,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: fgColor,
                  ),
                )
              else
                Icon(Icons.auto_awesome_rounded, size: 14, color: fgColor),
              const SizedBox(width: 5),
              Text(
                isLoading ? 'Kuting...' : label,
                style: TextStyle(
                  fontSize: compact ? 11.5 : 12,
                  fontWeight: FontWeight.w600,
                  color: fgColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Standalone screen wrapper for backward compatibility
class CardFormScreen extends StatelessWidget {
  final String deckId;
  final CardModel? card;

  const CardFormScreen({super.key, required this.deckId, this.card});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black54,
      body: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: CardFormModal(deckId: deckId, card: card),
        ),
      ),
    );
  }
}
