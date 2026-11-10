import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/tts_service.dart';
import '../../core/utils/srs.dart';
import '../../models/card_model.dart';
import '../../models/deck_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/decks_provider.dart';
import '../../providers/cards_provider.dart';
import '../../widgets/skeleton/app_skeleton.dart';
import '../study/study_screen.dart';
import '../quiz/quiz_setup_screen.dart';
import 'card_form_screen.dart';
import 'ai_scan_screen.dart';
import '../../widgets/custom_study_modal.dart';

class DeckDetailScreen extends StatefulWidget {
  final String deckId;
  const DeckDetailScreen({super.key, required this.deckId});

  @override
  State<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends State<DeckDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentAudioIndex = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CardsProvider>().loadCardsForDeck(widget.deckId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    TtsService.instance.stop();
    super.dispose();
  }

  void _confirmDeleteDeck(BuildContext context, DeckModel deck) {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final decksProv = context.read<DecksProvider>();
    final cardsProv = context.read<CardsProvider>();
    final userId = context.read<AuthProvider>().user?.id;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('To\'plam o\'chirilsinmi?'),
        content: const Text(
          'Barcha so\'zlar ham o\'chiriladi. Bu amalni qaytarib bo\'lmaydi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (userId != null) {
                await decksProv.deleteDeck(deck.id, userId);
                await cardsProv.removeCardsForDeck(deck.id);
              }
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (mounted) {
                nav.pop(); // Go back to decks list
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('To\'plam o\'chirildi'),
                    backgroundColor: AppColors.destructive,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCard(BuildContext context, CardModel card) {
    final cardsProv = context.read<CardsProvider>();
    final decksProv = context.read<DecksProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('So\'zni o\'chirish?'),
        content: Text('"${card.word}" so\'zi butunlay o\'chiriladi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () async {
              await cardsProv.deleteCard(card.id, widget.deckId);
              if (ctx.mounted) {
                decksProv.updateCardCount(widget.deckId, -1);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            child: const Text('O\'chirish'),
          ),
        ],
      ),
    );
  }

  void _startListenAndLearn(List<CardModel> cards) {
    if (cards.isEmpty) return;
    final words = cards
        .map((c) => {'word': c.word, 'translation': c.translation})
        .toList();

    TtsService.instance.playWordSequence(
      words: words,
      onIndexChanged: (idx) {
        if (mounted) setState(() => _currentAudioIndex = idx);
      },
      onCompleted: () {
        if (mounted) setState(() => _currentAudioIndex = -1);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final decksProv = context.watch<DecksProvider>();
    final cardsProv = context.watch<CardsProvider>();

    final deck = decksProv.decks.firstWhere(
      (d) => d.id == widget.deckId,
      orElse: () => DeckModel(
        id: widget.deckId,
        userId: '',
        name: 'To\'plam',
        icon: '📚',
        color: 'violet',
      ),
    );

    final cards = cardsProv.getCardsForDeck(widget.deckId);

    // Show shimmer skeleton when deck cards are loading for the first time
    if (cardsProv.isDeckInitialLoading(widget.deckId) && cards.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(deck.name)),
        body: const DeckDetailScreenSkeleton(),
      );
    }
    final today = SrsAlgorithm.todayISO();
    final dueCount = cards.where((c) => c.dueDate.compareTo(today) <= 0).length;

    final totalReviews = cards.fold<int>(0, (sum, c) => sum + c.totalReviews);
    final correctReviews = cards.fold<int>(
      0,
      (sum, c) => sum + c.correctReviews,
    );
    final accuracy = totalReviews > 0
        ? ((correctReviews / totalReviews) * 100).round()
        : 0;

    final filtered = cards.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return c.word.toLowerCase().contains(q) ||
          c.translation.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(deck.icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                deck.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_rounded, color: AppColors.accent),
            tooltip: 'Rasmdan so\'z qo\'shish (AI Scan)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AiScanScreen(targetDeckId: widget.deckId),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Moslashuvchan mashq (Random / Oraliq)',
            onPressed: cards.isNotEmpty
                ? () => CustomStudyModal.show(
                      context,
                      deck: deck,
                      cards: cards,
                    )
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'JSON import',
            onPressed: () =>
                showAddWordModal(context, deckId: widget.deckId, initialTab: 1),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.destructive,
            ),
            tooltip: 'To\'plamni o\'chirish',
            onPressed: () => _confirmDeleteDeck(context, deck),
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              await context.read<CardsProvider>().loadCardsForDeck(
                widget.deckId,
                force: true,
              );
            },
            child: CustomScrollView(
              scrollCacheExtent: const ScrollCacheExtent.pixels(500),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Stats Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildMiniStatCard(
                                label: 'JAMI SO\'ZLAR',
                                value: '${cards.length}',
                                textColor: isDark
                                    ? AppColors.darkText
                                    : AppColors.lightText,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMiniStatCard(
                                label: 'BUGUN TAKRORLASH',
                                value: '$dueCount',
                                textColor: AppColors.accent,
                                borderColor: AppColors.accent.withValues(
                                  alpha: 0.5,
                                ),
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildMiniStatCard(
                                label: 'O\'ZLASHTIRISH',
                                value: '$accuracy%',
                                textColor: AppColors.success,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // 2. Play / Study & Audio action buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: cards.isNotEmpty
                                    ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => StudyScreen(
                                              deckId: widget.deckId,
                                              forceAllCards: dueCount == 0,
                                            ),
                                          ),
                                        );
                                      }
                                    : null,
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 22,
                                ),
                                label: Text(
                                  dueCount > 0
                                      ? 'Takrorlash ($dueCount)'
                                      : (cards.isNotEmpty
                                            ? 'Barchasini ko\'rish'
                                            : 'Kartalar yo\'q'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ValueListenableBuilder<bool>(
                              valueListenable:
                                  TtsService.instance.isPlayingNotifier,
                              builder: (context, isPlaying, _) {
                                return OutlinedButton.icon(
                                  onPressed: () {
                                    if (isPlaying) {
                                      TtsService.instance.stop();
                                    } else {
                                      _startListenAndLearn(cards);
                                    }
                                  },
                                  icon: Icon(
                                    isPlaying
                                        ? Icons.stop_rounded
                                        : Icons.volume_up_rounded,
                                    size: 20,
                                    color: isPlaying
                                        ? AppColors.destructive
                                        : null,
                                  ),
                                  label: Text(
                                    isPlaying
                                        ? 'To\'xtatish'
                                        : 'Eshitib yodlash',
                                    style: TextStyle(
                                      color: isPlaying
                                          ? AppColors.destructive
                                          : null,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 16,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 3. Quiz & New Word action row
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: cards.length >= 4
                                    ? () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => QuizSetupScreen(
                                              deck: deck,
                                              cards: cards,
                                            ),
                                          ),
                                        );
                                      }
                                    : () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Quiz uchun kamida 4 ta so\'z kerak',
                                                ),
                                              ),
                                            );
                                      },
                                icon: const Icon(Icons.quiz_rounded, size: 18),
                                label: const Text('Quiz boshlash'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => showAddWordModal(
                                  context,
                                  deckId: widget.deckId,
                                ),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Yangi so\'z'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark
                                      ? AppColors.darkSecondary
                                      : AppColors.brand,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // 4. Custom Scope Study Button
                        OutlinedButton.icon(
                          onPressed: cards.isNotEmpty
                              ? () => CustomStudyModal.show(
                                    context,
                                    deck: deck,
                                    cards: cards,
                                  )
                              : null,
                          icon: const Icon(Icons.tune_rounded, size: 18),
                          label: const Text(
                            'Moslashuvchan mashq (Random / Oraliq)',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(
                              color: (isDark
                                      ? AppColors.brandDark
                                      : AppColors.brand)
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 4. Search Bar
                        if (cards.isNotEmpty)
                          TextFormField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'So\'z qidirish...',
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 20,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (v) =>
                                setState(() => _searchQuery = v.trim()),
                          ),
                        const SizedBox(height: 14),

                        // 5. Words List Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'So\'zlar ro\'yxati',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${filtered.length} ta topildi',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),

                // 6. Virtualized Cards List
                if (filtered.isEmpty && cardsProv.isLoading)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => AppShimmer(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkCard
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SkeletonLine(width: 130, height: 16),
                                        SizedBox(height: 6),
                                        SkeletonLine(width: 180, height: 13),
                                      ],
                                    ),
                                  ),
                                  SkeletonCircle(size: 32),
                                  SizedBox(width: 8),
                                  SkeletonCircle(size: 32),
                                ],
                              ),
                            ),
                          ),
                        ),
                        childCount: 3,
                      ),
                    ),
                  )
                else if (filtered.isEmpty)
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 40,
                        horizontal: 24,
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cards.isEmpty
                                ? Icons.style_outlined
                                : Icons.search_off_rounded,
                            size: 48,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            cards.isEmpty
                                ? 'Hozircha so\'z yo\'q'
                                : 'So\'z topilmadi',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.lightTextMuted,
                            ),
                          ),
                          if (cards.isEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Yangi so\'z yoki JSON orqali birdaniga bir nechta so\'zlarni tezkor yuklang.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => showAddWordModal(
                                context,
                                deckId: widget.deckId,
                              ),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Yangi so\'z qo\'shish'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E293B),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    sliver: SliverList.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final card = filtered[index];
                        return _buildCardItem(context, card, isDark);
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Floating Audio Player Overlay
          ValueListenableBuilder<bool>(
            valueListenable: TtsService.instance.isPlayingNotifier,
            builder: (context, isPlaying, _) {
              if (!isPlaying) return const SizedBox.shrink();

              return Positioned(
                left: 16,
                right: 16,
                bottom: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.brandDark,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.volume_up_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'O\'qilmoqda ${_currentAudioIndex + 1}/${cards.length}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _currentAudioIndex >= 0 &&
                                      _currentAudioIndex < cards.length
                                  ? cards[_currentAudioIndex].word
                                  : '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.stop_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () => TtsService.instance.stop(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard({
    required String label,
    required String value,
    required Color textColor,
    Color? borderColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color:
              borderColor ??
              (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: borderColor != null ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.darkTextMuted
                  : AppColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardItem(BuildContext context, CardModel card, bool isDark) {
    return RepaintBoundary(
      key: ValueKey(card.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.volume_up_rounded, size: 22),
            color: AppColors.brandDark,
            onPressed: () => TtsService.instance.speak(card.word),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () =>
                  showAddWordModal(context, deckId: widget.deckId, card: card),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.word,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    card.translation,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: AppColors.destructive,
            onPressed: () => _confirmDeleteCard(context, card),
          ),
        ],
      ),
    ),
  );
}
}
