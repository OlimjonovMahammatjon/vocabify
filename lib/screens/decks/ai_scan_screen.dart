import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/ai_scan_service.dart';
import '../../models/deck_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cards_provider.dart';
import '../../providers/decks_provider.dart';
import '../../widgets/ai_settings_dialog.dart';
import 'deck_detail_screen.dart';

class AiScanScreen extends StatefulWidget {
  final String? targetDeckId;
  const AiScanScreen({super.key, this.targetDeckId});

  @override
  State<AiScanScreen> createState() => _AiScanScreenState();
}

class _AiScanScreenState extends State<AiScanScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;

  ScanFocusMode _focusMode = ScanFocusMode.highlighted;
  final TextEditingController _customNoteController = TextEditingController();
  final TextEditingController _deckNameController = TextEditingController();

  bool _isAnalyzing = false;
  String _statusText = '';
  AiScanResult? _scanResult;
  List<ExtractedWordItem> _words = [];

  String? _selectedExistingDeckId;
  bool _createNewDeck = true;

  @override
  void initState() {
    super.initState();
    _selectedExistingDeckId = widget.targetDeckId;
    if (widget.targetDeckId != null) {
      _createNewDeck = false;
    }
  }

  @override
  void dispose() {
    _customNoteController.dispose();
    _deckNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (file != null) {
        setState(() {
          _selectedImage = File(file.path);
          _scanResult = null;
          _words = [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rasm tanlashda xatolik: $e'),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    }
  }

  Future<void> _startAiAnalysis() async {
    if (_selectedImage == null) return;

    // Check if any API key is set
    final hasKey = await AiScanService.instance.hasAnyApiKey();
    if (!hasKey) {
      if (!mounted) return;
      final bool? keyAdded = await showAiSettingsDialog(context);
      if (keyAdded != true) return;
    }

    final activeProvider = await AiScanService.instance.getActiveProvider();
    if (!mounted) return;
    setState(() {
      _isAnalyzing = true;
      _statusText = activeProvider == AiProvider.gemini
          ? 'Gemini AI orqali rasm tahlil qilinmoqda... ✨'
          : 'Groq LPU orqali tezkor tahlil qilinmoqda... ⚡';
    });

    try {
      final result = await AiScanService.instance.scanImage(
        imageFile: _selectedImage!,
        focusMode: _focusMode,
        extraInstructions: _customNoteController.text.trim().isNotEmpty
            ? _customNoteController.text.trim()
            : null,
      );

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _scanResult = result;
          _words = result.words;
          _deckNameController.text = result.suggestedDeckName;
        });

        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result.words.length} ta so\'z muvaffaqiyatli aniqlandi! (${result.providerName}) ⚡',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        final errorMessage = e.toString().replaceAll('Exception:', '').trim();
        _showErrorDialog(errorMessage);
      }
    }
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppColors.destructive),
            SizedBox(width: 8),
            Text('Tahlilda xatolik'),
          ],
        ),
        content: Text(
          error,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              showAiSettingsDialog(context, showSavedSnackBar: true);
            },
            child: const Text('API kalitni o\'zgartirish'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tushundim'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndCreateDeck() async {
    final selectedWords = _words.where((w) => w.isSelected).toList();
    if (selectedWords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Iltimos, kamida bitta so\'zni tanlang.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final decksProv = context.read<DecksProvider>();
    final cardsProv = context.read<CardsProvider>();
    final userId = auth.user?.id;

    if (userId == null) return;

    setState(() => _isAnalyzing = true);
    HapticFeedback.selectionClick();

    try {
      String finalDeckId;
      DeckModel? createdDeck;

      if (_createNewDeck) {
        final deckName = _deckNameController.text.trim().isNotEmpty
            ? _deckNameController.text.trim()
            : 'Rasmdan yangi so\'zlar';

        createdDeck = await decksProv.createDeck(
          userId: userId,
          name: deckName,
          description: 'AI orqali rasmdan avtomatik yaratilgan to\'plam',
          icon: '📸',
          color: 'violet',
        );

        if (createdDeck == null) {
          throw Exception('To\'plamni yaratib bo\'lmadi.');
        }
        finalDeckId = createdDeck.id;
      } else {
        if (_selectedExistingDeckId == null || _selectedExistingDeckId!.isEmpty) {
          throw Exception('Mavjud to\'plam tanlanmagan.');
        }
        finalDeckId = _selectedExistingDeckId!;
        createdDeck = decksProv.decks.firstWhere((d) => d.id == finalDeckId);
      }

      // Prepare batch card payload
      final cardsData = selectedWords
          .map((item) => {
                'word': item.word,
                'translation': item.translation,
                if (item.pronunciation != null) 'pronunciation': item.pronunciation,
                if (item.definition != null) 'definition': item.definition,
                if (item.example != null) 'example_sentence': item.example,
              })
          .toList();

      final importedCount = await cardsProv.bulkImportCards(
        deckId: finalDeckId,
        userId: userId,
        items: cardsData,
      );

      decksProv.updateCardCount(finalDeckId, importedCount);

      if (mounted) {
        setState(() => _isAnalyzing = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DeckDetailScreen(deckId: finalDeckId),
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${createdDeck.name} to\'plamiga $importedCount ta so\'z muvaffaqiyatli saqlandi! ✨',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saqlashda xatolik: $e'),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    }
  }

  void _editWordDialog(int index) {
    final item = _words[index];
    final wordCtrl = TextEditingController(text: item.word);
    final transCtrl = TextEditingController(text: item.translation);
    final pronCtrl = TextEditingController(text: item.pronunciation ?? '');
    final defCtrl = TextEditingController(text: item.definition ?? '');
    final exCtrl = TextEditingController(text: item.example ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('So\'zni tahrirlash'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: wordCtrl,
                decoration: const InputDecoration(labelText: 'Inglizcha so\'z'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: transCtrl,
                decoration: const InputDecoration(labelText: 'O\'zbekcha tarjima'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pronCtrl,
                decoration: const InputDecoration(labelText: 'Talaffuz (IPA)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: defCtrl,
                decoration: const InputDecoration(labelText: 'Izoh (Definition)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: exCtrl,
                decoration: const InputDecoration(labelText: 'Misol gap'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () {
              if (wordCtrl.text.trim().isNotEmpty &&
                  transCtrl.text.trim().isNotEmpty) {
                setState(() {
                  item.word = wordCtrl.text.trim();
                  item.translation = transCtrl.text.trim();
                  item.pronunciation = pronCtrl.text.trim().isNotEmpty
                      ? pronCtrl.text.trim()
                      : null;
                  item.definition = defCtrl.text.trim().isNotEmpty
                      ? defCtrl.text.trim()
                      : null;
                  item.example = exCtrl.text.trim().isNotEmpty
                      ? exCtrl.text.trim()
                      : null;
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final decks = context.watch<DecksProvider>().decks;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 22),
            SizedBox(width: 8),
            Text('Rasmdan so\'zlar (AI Scan)'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt_rounded, color: Color(0xFFF59E0B)),
            tooltip: 'AI Vision sozlamalari (Groq / Gemini)',
            onPressed: () => showAiSettingsDialog(
              context,
              showSavedSnackBar: true,
            ),
          ),
        ],
      ),
      body: _isAnalyzing
          ? _buildLoadingState(isDark)
          : _scanResult != null
              ? _buildResultsView(isDark, decks)
              : _buildImageSelectorView(isDark),
      bottomNavigationBar: _scanResult != null && !_isAnalyzing
          ? _buildBottomBar(isDark)
          : null,
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.brandDark.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: CircularProgressIndicator(
                    strokeWidth: 3.5,
                    color: AppColors.brandDark,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Gemini Vision AI',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _statusText,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSelectorView(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF1E3A5F), const Color(0xFF14243B)]
                    : [AppColors.brand, const Color(0xFF283B60)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.camera_enhance_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rasmga tushiring yoki yuklang',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Kitobdagi markerlangan so\'zlar, tagiga chizilganlar yoki lug\'at daftaringizdan bir zumda to\'plam tayyorlaydi.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Image Preview or Placeholder
          if (_selectedImage != null) ...[
            Container(
              height: 240,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1.5,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(_selectedImage!, fit: BoxFit.cover),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: CircleAvatar(
                      backgroundColor: Colors.black.withValues(alpha: 0.65),
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                        onPressed: () => setState(() => _selectedImage = null),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickImage(ImageSource.camera),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      height: 130,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_camera_rounded, size: 36, color: AppColors.brandDark),
                          SizedBox(height: 8),
                          Text(
                            'Kamera',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Rasmga tushirish',
                            style: TextStyle(fontSize: 11, color: AppColors.lightTextMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickImage(ImageSource.gallery),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      height: 130,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library_rounded, size: 36, color: AppColors.accent),
                          SizedBox(height: 8),
                          Text(
                            'Galereya',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            'Rasmni yuklash',
                            style: TextStyle(fontSize: 11, color: AppColors.lightTextMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // Focus Mode Selector
          Text(
            'QIDIRISH USULI (FOKUS)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 8),

          _buildFocusTile(
            title: 'Faqat belgilangan so\'zlar',
            subtitle: 'Markerlangan (highlighted) yoki tagiga chizilgan so\'zlar',
            icon: Icons.border_color_rounded,
            mode: ScanFocusMode.highlighted,
            color: const Color(0xFFF59E0B),
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildFocusTile(
            title: 'Lug\'at daftari (so\'zlar ro\'yxati)',
            subtitle: 'Daftardagi inglizcha va o\'zbekcha qo\'lyozma so\'zlar',
            icon: Icons.menu_book_rounded,
            mode: ScanFocusMode.vocabularyList,
            color: const Color(0xFF10B981),
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildFocusTile(
            title: 'Matndagi barcha yangi so\'zlar',
            subtitle: 'Butun sahifadagi eng muhim va qiziq so\'zlar',
            icon: Icons.article_rounded,
            mode: ScanFocusMode.allKeyWords,
            color: const Color(0xFF0EA5E9),
            isDark: isDark,
          ),

          const SizedBox(height: 18),
          TextField(
            controller: _customNoteController,
            decoration: const InputDecoration(
              labelText: 'Qo\'shimcha ko\'rsatma (ixtiyoriy)',
              hintText: 'Masalan: faqat fe\'llarni ol yoki sariq marker',
              prefixIcon: Icon(Icons.notes_rounded, size: 20),
            ),
          ),

          const SizedBox(height: 24),

          // Action Button
          ElevatedButton.icon(
            onPressed: _selectedImage != null ? _startAiAnalysis : null,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Rasmni tahlil qilish (AI Scan)'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFocusTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required ScanFocusMode mode,
    required Color color,
    required bool isDark,
  }) {
    final isSelected = _focusMode == mode;
    return InkWell(
      onTap: () => setState(() => _focusMode = mode),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.2 : 0.1)
              : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: isSelected ? color : AppColors.lightTextMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsView(bool isDark, List<DeckModel> decks) {
    final selectedCount = _words.where((w) => w.isSelected).length;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Provider & Model Info Badge
                if (_scanResult != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          size: 20,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_scanResult!.providerName} (${_scanResult!.modelName}) • ${_words.length} ta so\'z topildi ⚡',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFD97706),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Deck Target Configuration Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Text('Yangi to\'plam'),
                              selected: _createNewDeck,
                              onSelected: (val) => setState(() => _createNewDeck = true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (decks.isNotEmpty)
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('Mavjud to\'plam'),
                                selected: !_createNewDeck,
                                onSelected: (val) => setState(() => _createNewDeck = false),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_createNewDeck)
                        TextField(
                          controller: _deckNameController,
                          decoration: const InputDecoration(
                            labelText: 'To\'plam nomi',
                            prefixIcon: Icon(Icons.bookmark_added_rounded, size: 20),
                          ),
                        )
                      else if (decks.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: _selectedExistingDeckId ?? decks.first.id,
                          decoration: const InputDecoration(labelText: 'To\'plamni tanlang'),
                          items: decks
                              .map(
                                (d) => DropdownMenuItem(
                                  value: d.id,
                                  child: Text('${d.icon} ${d.name}'),
                                ),
                              )
                              .toList(),
                          onChanged: (val) => setState(() => _selectedExistingDeckId = val),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Controls header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOPILGAN SO\'ZLAR (${_words.length})',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        final allSelected = selectedCount == _words.length;
                        setState(() {
                          for (final w in _words) {
                            w.isSelected = !allSelected;
                          }
                        });
                      },
                      icon: Icon(
                        selectedCount == _words.length
                            ? Icons.deselect_rounded
                            : Icons.select_all_rounded,
                        size: 18,
                      ),
                      label: Text(
                        selectedCount == _words.length ? 'Bekor qilish' : 'Barchasi',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // List of extracted words
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = _words[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: item.isSelected
                            ? (isDark ? AppColors.brandDark : AppColors.brand)
                            : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        width: item.isSelected ? 1.4 : 1.0,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: Checkbox(
                        value: item.isSelected,
                        activeColor: isDark ? AppColors.brandDark : AppColors.brand,
                        onChanged: (val) => setState(() => item.isSelected = val ?? false),
                      ),
                      title: Row(
                        children: [
                          Text(
                            item.word,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          if (item.pronunciation != null && item.pronunciation!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              item.pronunciation!,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            item.translation,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (item.example != null && item.example!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.example!,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () => _editWordDialog(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.destructive),
                            onPressed: () {
                              setState(() => _words.removeAt(index));
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              childCount: _words.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildBottomBar(bool isDark) {
    final selectedCount = _words.where((w) => w.isSelected).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _scanResult = null),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(80, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Qayta olish'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: selectedCount > 0 ? _saveAndCreateDeck : null,
                icon: const Icon(Icons.check_circle_rounded),
                label: Text('To\'plamni saqlash ($selectedCount ta so\'z)'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
