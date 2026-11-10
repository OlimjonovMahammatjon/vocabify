import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/tts_service.dart';
import '../../core/utils/srs.dart';
import '../../core/utils/helpers.dart';
import '../../models/card_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cards_provider.dart';
import '../../providers/study_provider.dart';
import '../../providers/stats_provider.dart';

class StudyScreen extends StatefulWidget {
  final String? deckId;
  final bool startInTypingMode;
  final bool forceAllCards;
  final List<CardModel>? customCards;

  const StudyScreen({
    super.key,
    this.deckId,
    this.startInTypingMode = false,
    this.forceAllCards = false,
    this.customCards,
  });

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  final TextEditingController _typingInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutCubic),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().user?.id;
      if (userId != null) {
        context.read<StudyProvider>().initSession(
          userId: userId,
          deckId: widget.deckId,
          startInTypingMode: widget.startInTypingMode,
          forceAllCards: widget.forceAllCards,
          customCards: widget.customCards,
        );
      }
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    _typingInputController.dispose();
    super.dispose();
  }

  void _handleFlip(StudyProvider study) {
    HapticFeedback.selectionClick();
    if (study.isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    study.flipCard();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final study = context.watch<StudyProvider>();
    final auth = context.watch<AuthProvider>();

    if (study.isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: isDark ? AppColors.brandDark : AppColors.brand,
              ),
              const SizedBox(height: 16),
              const Text('Kartalar yuklanmoqda...'),
            ],
          ),
        ),
      );
    }

    if (study.queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                const Text(
                  'Hozircha takrorlash yo\'q',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Yangi so\'z qo\'shing yoki ertaga qayting',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Bosh sahifaga qaytish'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (study.isFinished) {
      return _buildCelebrationScreen(context, study, isDark);
    }

    final card = study.currentCard;
    if (card == null) return const SizedBox.shrink();

    final progress = (study.currentIndex / study.queue.length).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: progress),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          builder: (context, val, _) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: val,
                minHeight: 8,
                backgroundColor: isDark
                    ? AppColors.darkSecondary
                    : AppColors.lightSecondary,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? AppColors.brandDark : AppColors.brand,
                ),
              ),
            );
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${study.currentIndex + 1}/${study.queue.length}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Mode Switcher Pills
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSecondary
                      : AppColors.lightSecondary,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          if (study.isTypingMode) {
                            _flipController.reset();
                            study.setTypingMode(false);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !study.isTypingMode
                                ? (isDark ? AppColors.darkCard : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: !study.isTypingMode
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.06,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.style_rounded,
                                size: 18,
                                color: !study.isTypingMode
                                    ? (isDark
                                          ? Colors.white
                                          : AppColors.lightText)
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Kartochka',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: !study.isTypingMode
                                      ? (isDark
                                            ? Colors.white
                                            : AppColors.lightText)
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          if (!study.isTypingMode) {
                            _flipController.reset();
                            study.setTypingMode(true);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: study.isTypingMode
                                ? (isDark ? AppColors.darkCard : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: study.isTypingMode
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.06,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.keyboard_rounded,
                                size: 18,
                                color: study.isTypingMode
                                    ? (isDark
                                          ? Colors.white
                                          : AppColors.lightText)
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Yozish',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: study.isTypingMode
                                      ? (isDark
                                            ? Colors.white
                                            : AppColors.lightText)
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Card Area (Flashcard 3D flip OR Typing card)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: AnimatedSlide(
                  offset: study.exitAnim == 'left'
                      ? const Offset(-1.25, 0.0)
                      : study.exitAnim == 'right'
                      ? const Offset(1.25, 0.0)
                      : Offset.zero,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeInCubic,
                  child: AnimatedRotation(
                    turns: study.exitAnim == 'left'
                        ? -0.04
                        : study.exitAnim == 'right'
                        ? 0.04
                        : 0.0,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInCubic,
                    child: AnimatedOpacity(
                      opacity: study.exitAnim != null ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 240),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        transitionBuilder: (child, anim) {
                          return FadeTransition(
                            opacity: anim,
                            child: ScaleTransition(
                              scale: Tween<double>(
                                begin: 0.94,
                                end: 1.0,
                              ).animate(anim),
                              child: child,
                            ),
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey('${card.id}_${study.isTypingMode}'),
                          child: study.isTypingMode
                              ? _buildTypingCard(context, card, study, isDark)
                              : _build3DFlipCard(context, card, study, isDark),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Buttons Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: study.isTypingMode
                  ? _buildTypingFooter(context, study, auth)
                  : _buildCardsFooter(context, card, study, auth),
            ),
          ],
        ),
      ),
    );
  }

  Widget _build3DFlipCard(
    BuildContext context,
    CardModel card,
    StudyProvider study,
    bool isDark,
  ) {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final angle = _flipAnimation.value * pi;
        final isFront = angle < pi / 2;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0014) // smooth realistic perspective
            ..rotateY(angle),
          alignment: Alignment.center,
          child: isFront
              ? _buildCardFront(context, card, study, isDark)
              : Transform(
                  transform: Matrix4.identity()..rotateY(pi),
                  alignment: Alignment.center,
                  child: _buildCardBack(context, card, study, isDark),
                ),
        );
      },
    );
  }

  Widget _buildCardFront(
    BuildContext context,
    CardModel card,
    StudyProvider study,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () => _handleFlip(study),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'FRONT · BOSSING FLIP UCHUN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            Text(
              card.word,
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (card.pronunciation != null &&
                card.pronunciation!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '/${card.pronunciation}/',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted,
                ),
              ),
            ],
            const SizedBox(height: 18),
            IconButton.filledTonal(
              iconSize: 28,
              padding: const EdgeInsets.all(16),
              icon: const Icon(Icons.volume_up_rounded),
              onPressed: () => TtsService.instance.speak(card.word),
            ),
            const Spacer(),
            Text(
              'Javobni ko\'rish uchun bosing',
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
    );
  }

  Widget _buildCardBack(
    BuildContext context,
    CardModel card,
    StudyProvider study,
    bool isDark,
  ) {
    return GestureDetector(
      onTap: () => _handleFlip(study),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'JAVOB',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                card.word,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                card.translation,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.brandDark : AppColors.brand,
                ),
              ),
              const SizedBox(height: 16),

              if (card.definition != null && card.definition!.isNotEmpty) ...[
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                    children: [
                      TextSpan(
                        text: 'Izoh: ',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(text: card.definition),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              if (card.synonyms != null && card.synonyms!.isNotEmpty) ...[
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                    children: [
                      TextSpan(
                        text: 'Sinonim: ',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(text: card.synonyms),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              if (card.antonyms != null && card.antonyms!.isNotEmpty) ...[
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                    children: [
                      TextSpan(
                        text: 'Antonim: ',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(text: card.antonyms),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              if (card.exampleSentence != null &&
                  card.exampleSentence!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSecondary
                        : AppColors.lightSecondary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    card.exampleSentence!,
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingCard(
    BuildContext context,
    CardModel card,
    StudyProvider study,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'TARJIMAGA QARAB INGLIZCHA SO\'ZNI YOZING',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 14),

            // Translation Container
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSecondary
                    : AppColors.lightSecondary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tarjima',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.translation,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (card.definition != null &&
                      card.definition!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      card.definition!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Masked sentence
            if (card.exampleSentence != null &&
                card.exampleSentence!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Text(
                  AppHelpers.maskWord(card.exampleSentence!, card.word),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            const SizedBox(height: 16),

            // Text input
            TextFormField(
              controller: _typingInputController,
              enabled: !study.isTypingChecked,
              autofocus: true,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(hintText: 'So\'zni yozing...'),
              onChanged: (v) => study.updateTypedAnswer(v),
            ),
            const SizedBox(height: 10),

            // Hint row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: (!study.isTypingChecked && study.hintLevel < 2)
                      ? () => study.revealHint()
                      : null,
                  icon: const Icon(Icons.lightbulb_outline_rounded, size: 16),
                  label: const Text('Yordam'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
                Text(
                  'Urinish: ${study.typingAttempts}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                ),
              ],
            ),

            if (study.hintLevel > 0 && !study.isTypingChecked) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.brandDark.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  AppHelpers.getWordHint(card.word, study.hintLevel),
                  style: const TextStyle(
                    color: AppColors.brandDark,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],

            // Checked Result
            if (study.isTypingChecked) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: study.isTypingCorrect
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.destructive.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: study.isTypingCorrect
                        ? AppColors.success.withValues(alpha: 0.4)
                        : AppColors.destructive.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          study.isTypingCorrect
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          color: study.isTypingCorrect
                              ? AppColors.success
                              : AppColors.destructive,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          study.isTypingCorrect
                              ? 'To\'g\'ri yozdingiz!'
                              : 'Javob mos kelmadi',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: study.isTypingCorrect
                                ? AppColors.success
                                : AppColors.destructive,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'To\'g\'ri javob: ${card.word}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCardsFooter(
    BuildContext context,
    CardModel card,
    StudyProvider study,
    AuthProvider auth,
  ) {
    if (!study.isFlipped) {
      return ElevatedButton(
        onPressed: () => _handleFlip(study),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: const Text(
          'Javobni ko\'rsatish',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    final userId = auth.user?.id ?? '';
    final profile = auth.profile;

    final hintTime = SrsAlgorithm.formatIntervalHint(
      SrsState(
        easeFactor: card.easeFactor,
        intervalDays: card.intervalDays,
        repetitions: card.repetitions,
      ),
      Rating.good,
    );

    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () async {
              await study.rate(
                Rating.again,
                userId: userId,
                currentProfile: profile,
                onProfileUpdated: auth.updateLocalProfile,
              );
              if (mounted) _flipController.reset();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.destructive.withValues(alpha: 0.12),
              foregroundColor: AppColors.destructive,
              minimumSize: const Size(0, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(
                  color: AppColors.destructive,
                  width: 1.5,
                ),
              ),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Bilmayman',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Text('Yana ko\'raman', style: TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: ElevatedButton(
            onPressed: () async {
              await study.rate(
                Rating.good,
                userId: userId,
                currentProfile: profile,
                onProfileUpdated: auth.updateLocalProfile,
              );
              if (mounted) _flipController.reset();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success.withValues(alpha: 0.12),
              foregroundColor: AppColors.success,
              minimumSize: const Size(0, 60),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: AppColors.success, width: 1.5),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Bilaman',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Text(hintTime, style: const TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypingFooter(
    BuildContext context,
    StudyProvider study,
    AuthProvider auth,
  ) {
    final userId = auth.user?.id ?? '';
    final profile = auth.profile;

    if (!study.isTypingChecked) {
      return ElevatedButton(
        onPressed: study.typedAnswer.trim().isNotEmpty
            ? () => study.submitTyping()
            : null,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: const Text('Tekshirish', style: TextStyle(fontSize: 16)),
      );
    }

    if (study.isTypingCorrect) {
      return ElevatedButton(
        onPressed: () async {
          _typingInputController.clear();
          await study.rate(
            study.getTypingRating(),
            userId: userId,
            currentProfile: profile,
            onProfileUpdated: auth.updateLocalProfile,
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: const Text('Keyingi', style: TextStyle(fontSize: 16)),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              _typingInputController.clear();
              await study.rate(
                Rating.again,
                userId: userId,
                currentProfile: profile,
                onProfileUpdated: auth.updateLocalProfile,
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.destructive,
              side: const BorderSide(color: AppColors.destructive),
              minimumSize: const Size(0, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text('Bilmayman'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () async {
              _typingInputController.clear();
              await study.rate(
                Rating.good,
                userId: userId,
                currentProfile: profile,
                onProfileUpdated: auth.updateLocalProfile,
              );
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text('Bilaman'),
          ),
        ),
      ],
    );
  }

  Widget _buildCelebrationScreen(
    BuildContext context,
    StudyProvider study,
    bool isDark,
  ) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 48,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Ajoyib! 🎉',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                '${study.totalDone} ta so\'z takrorladingiz',
                style: TextStyle(
                  fontSize: 15,
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted,
                ),
              ),
              const SizedBox(height: 28),

              // 4 Stat boxes
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildCelebrationBox(
                            'Aniqlik',
                            '${study.accuracy}%',
                            isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCelebrationBox(
                            'Jami',
                            '${study.totalDone}',
                            isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCelebrationBox(
                            'Bilganlar',
                            '${study.countGood + study.countEasy + study.countHard}',
                            isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCelebrationBox(
                            'Bilmaganlar',
                            '${study.countAgain}',
                            isDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final userId = context.read<AuthProvider>().user?.id;
                          if (userId != null) {
                            study.initSession(
                              userId: userId,
                              deckId: widget.deckId,
                              startInTypingMode: widget.startInTypingMode,
                            );
                          }
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Yana'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final uid = context.read<AuthProvider>().user?.id;
                          if (uid != null) {
                            context.read<StatsProvider>().loadStats(
                                  uid,
                                  force: true,
                                );
                            if (widget.deckId != null) {
                              context.read<CardsProvider>().loadCardsForDeck(
                                    widget.deckId!,
                                    force: true,
                                  );
                            }
                            context.read<CardsProvider>().loadAllCards(
                                  uid,
                                  force: true,
                                );
                          }
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Tugatish'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCelebrationBox(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.darkTextMuted
                  : AppColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}
