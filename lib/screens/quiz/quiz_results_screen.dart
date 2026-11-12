import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../widgets/motion/app_motion.dart';
import '../../models/card_model.dart';
import '../../models/deck_model.dart';
import '../../providers/quiz_provider.dart';
import 'quiz_setup_screen.dart';

class QuizResultsScreen extends StatelessWidget {
  final DeckModel deck;
  final List<CardModel> cards;
  final String direction;
  final List<QuizResultItem> results;

  const QuizResultsScreen({
    super.key,
    required this.deck,
    required this.cards,
    required this.direction,
    required this.results,
  });

  Map<String, dynamic> _getGrade(int percentage) {
    if (percentage >= 90) {
      return {'emoji': '🏆', 'label': 'Ajoyib!', 'color': AppColors.success};
    }
    if (percentage >= 75) {
      return {'emoji': '🎉', 'label': 'Yaxshi!', 'color': AppColors.success};
    }
    if (percentage >= 60) {
      return {
        'emoji': '👍',
        'label': 'Yaxshi harakat!',
        'color': AppColors.accent,
      };
    }
    return {'emoji': '📚', 'label': 'Mashq qiling!', 'color': Colors.grey};
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final correctCount = results.where((r) => r.isCorrect).length;
    final wrongCount = results.length - correctCount;
    final percentage = results.isNotEmpty
        ? ((correctCount / results.length) * 100).round()
        : 0;
    final grade = _getGrade(percentage);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NATIJA',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
                color: isDark
                    ? AppColors.darkTextMuted
                    : AppColors.lightTextMuted,
              ),
            ),
            const Text(
              'Quiz yakunlandi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Score Summary Card
            StaggeredEntrance(
              index: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    grade['emoji'] as String,
                    style: const TextStyle(fontSize: 54),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    grade['label'] as String,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: grade['color'] as Color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedCountText(
                    value: percentage,
                    suffix: '%',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$correctCount',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'To\'g\'ri',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        height: 36,
                        width: 1,
                        color: isDark
                            ? AppColors.darkBorder
                            : AppColors.lightBorder,
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.cancel_rounded,
                            color: AppColors.destructive,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$wrongCount',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Noto\'g\'ri',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.lightTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              ),
            ),
            const SizedBox(height: 20),

            // Review Answers Card
            StaggeredEntrance(
              index: 1,
              child: Container(
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
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: const Text(
                      'Javoblarni ko\'rish',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                  Column(
                    children: [
                      for (int i = 0; i < results.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            color: isDark
                                ? AppColors.darkBorder
                                : AppColors.lightBorder,
                          ),
                        _buildResultRow(results[i], i),
                      ],
                    ],
                  ),
                ],
              ),
              ),
            ),
            const SizedBox(height: 20),

            // Actions
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuizSetupScreen(deck: deck, cards: cards),
                  ),
                );
              },
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Qayta boshlash'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('To\'plamga qaytish'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(QuizResultItem item, int index) {
    final questionWord =
        direction == 'en-uz' ? item.card.word : item.card.translation;
    final correctAnswer =
        direction == 'en-uz' ? item.card.translation : item.card.word;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            item.isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: item.isCorrect ? AppColors.success : AppColors.destructive,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}. $questionWord',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '✓ $correctAnswer',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!item.isCorrect && item.selectedAnswer.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '✗ ${item.selectedAnswer}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.destructive,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
