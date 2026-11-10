import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/tts_service.dart';
import '../../models/card_model.dart';
import '../../models/deck_model.dart';
import '../../providers/quiz_provider.dart';
import 'quiz_results_screen.dart';

class QuizPlayScreen extends StatefulWidget {
  final DeckModel deck;
  final List<CardModel> cards;
  final String direction;

  const QuizPlayScreen({
    super.key,
    required this.deck,
    required this.cards,
    required this.direction,
  });

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  bool _hasNavigatedToResults = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuizProvider>().initQuiz(
        deck: widget.deck,
        cards: widget.cards,
        direction: widget.direction,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final quiz = context.watch<QuizProvider>();

    if (quiz.isQuizFinished) {
      if (!_hasNavigatedToResults) {
        _hasNavigatedToResults = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => QuizResultsScreen(
                deck: widget.deck,
                cards: widget.cards,
                direction: widget.direction,
                results: quiz.results,
              ),
            ),
          );
        });
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final q = quiz.currentQuestion;
    if (q == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final questionWord = quiz.direction == 'en-uz'
        ? q.card.word
        : q.card.translation;
    final optionLabels = ['A', 'B', 'C', 'D'];
    final progress = ((quiz.currentIndex + 1) / quiz.questions.length).clamp(
      0.0,
      1.0,
    );
    final isUrgentTime = quiz.timeLeft <= 10;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Text(
              '${quiz.currentIndex + 1} / ${quiz.questions.length}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSecondary
                    : AppColors.lightSecondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                quiz.direction == 'en-uz' ? 'EN → UZ' : 'UZ → EN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.darkTextMuted
                      : AppColors.lightTextMuted,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 18,
                  color: isUrgentTime ? AppColors.destructive : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  '${quiz.timeLeft}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isUrgentTime ? AppColors.destructive : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Linear Progress Bar
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: progress),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              builder: (context, val, _) {
                return LinearProgressIndicator(
                  value: val,
                  minHeight: 4,
                  backgroundColor: isDark
                      ? AppColors.darkSecondary
                      : AppColors.lightSecondary,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? AppColors.brandDark : AppColors.brand,
                  ),
                );
              },
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Question Card with smooth slide & fade transition
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) {
                        return FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.08, 0.0),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        key: ValueKey(q.card.id),
                        padding: const EdgeInsets.symmetric(
                          vertical: 24,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.2 : 0.05,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              quiz.direction == 'en-uz'
                                  ? 'TARJIMASINI TOPING'
                                  : 'BU NIMA DEGANI?',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    questionWord,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.volume_up_rounded),
                                  color: AppColors.brandDark,
                                  onPressed: () {
                                    final speakWord = quiz.direction == 'en-uz'
                                        ? q.card.word
                                        : q.card.translation;
                                    TtsService.instance.speak(speakWord);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Options (A, B, C, D)
                    ...List.generate(q.options.length, (i) {
                      final option = q.options[i];
                      final isSelected = quiz.selectedAnswer == option;
                      final isCorrect = option == q.correctAnswer;

                      Color? bgColor;
                      Color? borderColor;
                      Color? textColor;
                      Widget? iconTrailing;

                      if (quiz.isAnswered) {
                        if (isCorrect) {
                          bgColor = AppColors.success.withValues(alpha: 0.15);
                          borderColor = AppColors.success;
                          textColor = AppColors.success;
                          iconTrailing = const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                            size: 22,
                          );
                        } else if (isSelected) {
                          bgColor = AppColors.destructive.withValues(
                            alpha: 0.15,
                          );
                          borderColor = AppColors.destructive;
                          textColor = AppColors.destructive;
                          iconTrailing = const Icon(
                            Icons.cancel_rounded,
                            color: AppColors.destructive,
                            size: 22,
                          );
                        } else {
                          bgColor = isDark
                              ? AppColors.darkSecondary.withValues(alpha: 0.4)
                              : AppColors.lightSecondary.withValues(alpha: 0.5);
                          borderColor = isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder;
                        }
                      } else {
                        bgColor = isDark ? AppColors.darkCard : Colors.white;
                        borderColor = isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AnimatedScale(
                          scale: isSelected ? 1.02 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutBack,
                          child: InkWell(
                            onTap: quiz.isAnswered
                                ? null
                                : () => quiz.selectOption(option),
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 240),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: borderColor,
                                  width:
                                      (quiz.isAnswered &&
                                          (isCorrect || isSelected))
                                      ? 2
                                      : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color:
                                            textColor ??
                                            (isDark
                                                ? AppColors.darkTextMuted
                                                : AppColors.lightTextMuted),
                                        width: 1.5,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      optionLabels[i],
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      option,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  if (iconTrailing != null)
                                    TweenAnimationBuilder<double>(
                                      tween: Tween<double>(
                                        begin: 0.0,
                                        end: 1.0,
                                      ),
                                      duration: const Duration(
                                        milliseconds: 280,
                                      ),
                                      curve: Curves.elasticOut,
                                      builder: (context, scaleVal, child) =>
                                          Transform.scale(
                                            scale: scaleVal,
                                            child: child,
                                          ),
                                      child: iconTrailing,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
