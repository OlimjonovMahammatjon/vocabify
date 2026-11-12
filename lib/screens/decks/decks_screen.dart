import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../widgets/motion/app_motion.dart';
import '../../models/deck_model.dart';
import '../../models/card_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/decks_provider.dart';
import '../../providers/cards_provider.dart';
import '../../widgets/skeleton/app_skeleton.dart';
import '../../widgets/custom_study_modal.dart';
import '../bulk_import/bulk_import_screen.dart';
import 'deck_detail_screen.dart';
import 'ai_scan_screen.dart';

class DecksScreen extends StatefulWidget {
  final bool openCreateModalOnInit;
  const DecksScreen({super.key, this.openCreateModalOnInit = false});

  @override
  State<DecksScreen> createState() => _DecksScreenState();
}

class _DecksScreenState extends State<DecksScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final List<String> _icons = [
    "📚",
    "🎓",
    "💼",
    "🗣️",
    "✈️",
    "🍽️",
    "💻",
    "🎬",
    "🌍",
    "❤️",
  ];
  final List<String> _colors = ["violet", "amber", "emerald", "rose", "sky"];

  @override
  void initState() {
    super.initState();
    if (widget.openCreateModalOnInit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCreateDeckModal();
      });
    }
  }

  Future<void> _showCreateDeckModal() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String selectedIcon = "📚";
    String selectedColor = "violet";
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Yangi to\'plam',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Name
                  TextFormField(
                    controller: nameController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Nomi *',
                      hintText: 'IELTS Vocabulary',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextFormField(
                    controller: descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Tavsif (ixtiyoriy)',
                      hintText: 'Imtihon uchun so\'zlar...',
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Icon Picker
                  const Text(
                    'Belgi',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _icons.map((icon) {
                      final isSelected = selectedIcon == icon;
                      return InkWell(
                        onTap: () => setModalState(() => selectedIcon = icon),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark
                                      ? AppColors.brandDark
                                      : AppColors.brand)
                                : (isDark
                                      ? AppColors.darkSecondary
                                      : AppColors.lightSecondary),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            icon,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Color Picker
                  const Text(
                    'Rang',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: _colors.map((colorKey) {
                      final isSelected = selectedColor == colorKey;
                      final col = AppColors.deckColors[colorKey] ?? Colors.grey;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: InkWell(
                          onTap: () =>
                              setModalState(() => selectedColor = colorKey),
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: col,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: col.withValues(alpha: 0.6),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Submit button
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final name = nameController.text.trim();
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Nom kiriting')),
                              );
                              return;
                            }

                            final messenger = ScaffoldMessenger.of(context);
                            setModalState(() => isSubmitting = true);
                            final userId = context
                                .read<AuthProvider>()
                                .user
                                ?.id;
                            if (userId != null) {
                              await context.read<DecksProvider>().createDeck(
                                userId: userId,
                                name: name,
                                description: descController.text.trim(),
                                icon: selectedIcon,
                                color: selectedColor,
                              );
                            }

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            if (mounted) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('To\'plam yaratildi!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Yaratish'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    nameController.dispose();
    descController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final decksProv = context.watch<DecksProvider>();
    final decks = decksProv.decks;
    final allCards = context.watch<CardsProvider>().allCards;

    return Scaffold(
      appBar: AppBar(
        title: const Text('To\'plamlar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_rounded, color: AppColors.accent),
            tooltip: 'Rasmdan so\'zlar (AI Scan)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiScanScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.shuffle_rounded),
            tooltip: 'Aralash sinov',
            onPressed: allCards.isNotEmpty
                ? () => CustomStudyModal.show(
                      context,
                      cards: allCards,
                      isGlobal: true,
                    )
                : null,
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BulkImportScreen()),
              );
            },
            icon: const Icon(Icons.file_upload_outlined, size: 18),
            label: const Text('JSON import'),
            style: TextButton.styleFrom(
              foregroundColor: isDark
                  ? AppColors.darkText
                  : AppColors.lightText,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Yangi to\'plam',
            onPressed: _showCreateDeckModal,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body:
          (decks.isEmpty && (decksProv.isInitialLoading || decksProv.isLoading))
          ? const DecksScreenSkeleton()
          : decks.isEmpty
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('📚', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 16),
                    const Text(
                      'Hech qanday to\'plam yo\'q',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Boshlash uchun yangi to\'plam yarating',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _showCreateDeckModal,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Birinchi to\'plamni yaratish'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AiScanScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.accent),
                      label: const Text('Rasmdan so\'zlar (AI Scan)'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () async {
                final userId = context.read<AuthProvider>().user?.id;
                await context.read<DecksProvider>().loadDecks(
                  userId,
                  force: true,
                );
              },
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: decks.length + 1 + (allCards.isNotEmpty ? 1 : 0),
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildAiScanBanner(context, isDark);
                  }
                  if (allCards.isNotEmpty) {
                    if (index == 1) {
                      return _buildGlobalMixBanner(context, allCards, isDark);
                    }
                    final deck = decks[index - 2];
                    final card = _buildDeckCard(context, deck);
                    return index < 6
                        ? StaggeredEntrance(index: index, child: card)
                        : card;
                  }
                  final deck = decks[index - 1];
                  final card = _buildDeckCard(context, deck);
                  return index < 6
                      ? StaggeredEntrance(index: index, child: card)
                      : card;
                },
              ),
            ),
    );
  }

  Widget _buildAiScanBanner(BuildContext context, bool isDark) {
    return StaggeredEntrance(
      index: 0,
      child: PressScale(
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AiScanScreen()),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF152238) : AppColors.brand,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? AppColors.darkBorder
                    : Colors.white.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFFFF9E0B),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI orqali rasmdan to\'plam',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Kitobdagi belgilangan yoki daftardagi so\'zlarni oling',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white70,
              size: 14,
            ),
          ],
        ),
      ),
      ),
      ),
    );
  }

  Widget _buildGlobalMixBanner(
    BuildContext context,
    List<CardModel> allCards,
    bool isDark,
  ) {
    return StaggeredEntrance(
      index: 1,
      child: PressScale(
        child: InkWell(
      onTap: () => CustomStudyModal.show(
        context,
        cards: allCards,
        isGlobal: true,
      ),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (isDark ? AppColors.brandDark : AppColors.brand)
                .withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: (isDark ? AppColors.brandDark : AppColors.brand)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Text('🎲', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aralash Sinov',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Barcha to\'plamlardan tasodifiy mashq',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.brandDark : AppColors.brand,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${allCards.length} ta',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      ),
      ),
    );
  }

  Widget _buildDeckCard(BuildContext context, DeckModel deck) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = AppColors.deckColors[deck.color] ?? AppColors.brand;
    final bgColor = isDark
        ? (AppColors.deckBgDark[deck.color] ?? AppColors.darkCard)
        : (AppColors.deckBgLight[deck.color] ?? AppColors.lightCard);

    return PressScale(
      child: InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DeckDetailScreen(deckId: deck.id)),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: isDark ? 0.3 : 0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(deck.icon, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deck.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    deck.description?.isNotEmpty == true
                        ? deck.description!
                        : '${deck.cardCount} ta so\'z',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey,
              size: 24,
            ),
          ],
        ),
      ),
      ),
    );
  }
}
