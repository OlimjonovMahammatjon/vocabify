import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/tts_service.dart';
import '../../models/stats_data_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/stats_provider.dart';
import '../../widgets/skeleton/app_skeleton.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final List<String> _dayNames = ['Yak', 'Du', 'Se', 'Cho', 'Pa', 'Ju', 'Sha'];
  bool _showAllTroubleWords = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().user?.id;
      if (userId != null) {
        context.read<StatsProvider>().loadStats(userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statsProv = context.watch<StatsProvider>();
    final stats = statsProv.stats;

    // Show shimmering skeleton if stats are initial loading and no data exists yet
    if (statsProv.isInitialLoading && stats.totalCards == 0) {
      return Scaffold(
        appBar: AppBar(title: const Text('Statistika & Tahlil')),
        body: const StatsScreenSkeleton(),
      );
    }

    final goalProgress =
        (stats.reviewsToday / (stats.goal > 0 ? stats.goal : 1)).clamp(
          0.0,
          1.0,
        );
    final activeCards = stats.totalCards > 0 ? stats.totalCards : 1;
    final totalReviews = stats.totalReviews > 0 ? stats.totalReviews : 1;
    final wrongPercentage = ((stats.wrongReviews / totalReviews) * 100).round();
    final correctPercentage = ((stats.correctReviews / totalReviews) * 100)
        .round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistika & Tahlil'),
        actions: [
          IconButton(
            icon: statsProv.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: () {
              final userId = context.read<AuthProvider>().user?.id;
              if (userId != null) statsProv.loadStats(userId, force: true);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final userId = context.read<AuthProvider>().user?.id;
          if (userId != null) {
            await statsProv.loadStats(userId, force: true);
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Streak Banner & Overview
              _buildStreakBanner(stats, isDark),
              const SizedBox(height: 14),

              // 2. Top Stats 2x2 Grid (Streak, Total, Mastered, Accuracy)
              Row(
                children: [
                  Expanded(
                    child: _buildTopStat(
                      icon: Icons.local_fire_department_rounded,
                      iconColor: const Color(0xFFF97316),
                      label: 'Joriy streak',
                      value: '${stats.streak} kun',
                      subtitle: 'Rekord: ${stats.longest} kun',
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTopStat(
                      icon: Icons.library_books_rounded,
                      iconColor: AppColors.brandDark,
                      label: 'Barcha so\'zlar',
                      value: '${stats.totalCards} ta',
                      subtitle: 'Lug\'at hajmi',
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildTopStat(
                      icon: Icons.verified_rounded,
                      iconColor: AppColors.success,
                      label: 'Yodlangan',
                      value: '${stats.mastered} ta',
                      subtitle:
                          '${((stats.mastered / activeCards) * 100).round()}% mustahkam',
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTopStat(
                      icon: Icons.gps_fixed_rounded,
                      iconColor: const Color(0xFF6366F1),
                      label: 'Aniqlik',
                      value: '${stats.accuracy}%',
                      subtitle: '$correctPercentage% to\'g\'ri',
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 3. Daily Goal Card (Animated Smooth Progress Bar)
              Container(
                padding: const EdgeInsets.all(20),
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
                        alpha: isDark ? 0.2 : 0.04,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Kunlik maqsad',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${stats.reviewsToday} / ${stats.goal} ta so\'z takrorlandi',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.lightTextMuted,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color:
                                (stats.reviewsToday >= stats.goal
                                        ? AppColors.success
                                        : AppColors.brandDark)
                                    .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            stats.reviewsToday >= stats.goal
                                ? Icons.emoji_events_rounded
                                : Icons.track_changes_rounded,
                            color: stats.reviewsToday >= stats.goal
                                ? AppColors.success
                                : AppColors.brandDark,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: goalProgress),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      builder: (context, val, _) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: val,
                            minHeight: 12,
                            backgroundColor: isDark
                                ? AppColors.darkSecondary
                                : AppColors.lightSecondary,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              stats.reviewsToday >= stats.goal
                                  ? AppColors.success
                                  : (isDark
                                        ? AppColors.brandDark
                                        : AppColors.brand),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(goalProgress * 100).round()}% bajarildi',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextMuted
                                : AppColors.lightTextMuted,
                          ),
                        ),
                        Text(
                          stats.reviewsToday >= stats.goal
                              ? 'Maqsad bajarildi! 🎉'
                              : '${stats.goal - stats.reviewsToday} ta so\'z qoldi',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: stats.reviewsToday >= stats.goal
                                ? AppColors.success
                                : AppColors.brandDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. Mistakes vs Correct Reviews Card (Xatoliklar & To'g'ri javoblar)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Javoblar aniqligi & Xatolar',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Jami ${stats.totalReviews} ta javobdan tahlil',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.success.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 18,
                                      color: AppColors.success,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'To\'g\'ri javoblar',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppColors.darkTextMuted
                                            : AppColors.lightTextMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${stats.correctReviews} ta',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$correctPercentage% umumiy',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.destructive.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.destructive.withValues(
                                  alpha: 0.25,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.cancel_outlined,
                                      size: 18,
                                      color: AppColors.destructive,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Xato qilinganlar',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppColors.darkTextMuted
                                            : AppColors.lightTextMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${stats.wrongReviews} ta',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.destructive,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$wrongPercentage% xatolik',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 5. Trouble Words List (KO'P XATO QILINGAN SO'ZLAR)
              _buildTroubleWordsSection(stats, isDark),
              const SizedBox(height: 14),

              // 6. Vocabulary Progress Breakdown (Yangi, O'rganilmoqda, Mustahkam)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lug\'at Tarkibi & O\'zlashtirish',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Jami ${stats.totalCards} ta so\'zning o\'zlashtirish bosqichlari',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildProgressRow(
                      label: 'Yangi so\'zlar',
                      sublabel: 'Hali takrorlanmagan',
                      value: stats.newCards,
                      total: activeCards,
                      barColor: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 14),
                    _buildProgressRow(
                      label: 'O\'rganilmoqda',
                      sublabel: 'Faol o\'rganish bosqichida (1-2 marta)',
                      value: stats.learning,
                      total: activeCards,
                      barColor: AppColors.accent,
                    ),
                    const SizedBox(height: 14),
                    _buildProgressRow(
                      label: 'Mustahkam yodlangan',
                      sublabel: 'Xotirada mustahkamlangan (3+ marta)',
                      value: stats.mastered,
                      total: activeCards,
                      barColor: AppColors.success,
                    ),
                    const SizedBox(height: 14),
                    _buildProgressRow(
                      label: 'Bugun takrorlash kerak',
                      sublabel: 'SM-2 algoritmi bo\'yicha bugun kutilayotgan',
                      value: stats.dueToday,
                      total: activeCards,
                      barColor: const Color(0xFFF59E0B),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 7. 7-Day Activity Chart
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'So\'nggi 7 kunlik faoliyat',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kunlik takrorlangan so\'zlar soni',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextMuted
                            : AppColors.lightTextMuted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 180,
                      child: RepaintBoundary(
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY:
                                (stats.last7
                                    .map((e) => e.count)
                                    .fold<int>(
                                      1,
                                      (max, v) => v > max ? v : max,
                                    ) *
                                1.3),
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipItem:
                                    (group, groupIndex, rod, rodIndex) {
                                      return BarTooltipItem(
                                        '${rod.toY.round()} ta so\'z',
                                        const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                                    },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (val, meta) {
                                    final idx = val.toInt();
                                    if (idx >= 0 && idx < stats.last7.length) {
                                      final date = DateTime.tryParse(
                                        stats.last7[idx].date,
                                      );
                                      if (date != null) {
                                        final dayName =
                                            _dayNames[date.weekday % 7];
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: Text(
                                            dayName,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? AppColors.darkTextMuted
                                                  : AppColors.lightTextMuted,
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                            ),
                            gridData: const FlGridData(show: false),
                            borderData: FlBorderData(show: false),
                            barGroups: List.generate(stats.last7.length, (i) {
                              final count = stats.last7[i].count.toDouble();
                              return BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(
                                    toY: count,
                                    color: count > 0
                                        ? (isDark
                                              ? AppColors.brandDark
                                              : AppColors.brand)
                                        : (isDark
                                              ? AppColors.darkSecondary
                                              : AppColors.lightSecondary),
                                    width: 18,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(6),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 8. Rating Breakdown Mini Stats (Again, Hard, Good, Easy)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Baholash taqsimoti (SM-2)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildRatingStat(
                            label: 'Yana',
                            value: '${stats.ratingCounts.again}',
                            color: AppColors.destructive,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildRatingStat(
                            label: 'Qiyin',
                            value: '${stats.ratingCounts.hard}',
                            color: AppColors.warning,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildRatingStat(
                            label: 'Yaxshi',
                            value: '${stats.ratingCounts.good}',
                            color: AppColors.success,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildRatingStat(
                            label: 'Oson',
                            value: '${stats.ratingCounts.easy}',
                            color: AppColors.accent,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreakBanner(StatsDataModel stats, bool isDark) {
    final hasReviewedToday = stats.reviewsToday > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: hasReviewedToday
            ? const Color(0xFFD97706)
            : (isDark ? AppColors.darkCard : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasReviewedToday
              ? const Color(0xFFB45309)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        boxShadow: hasReviewedToday
            ? [
                BoxShadow(
                  color: const Color(0xFFD97706).withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: hasReviewedToday
                  ? Colors.white.withValues(alpha: 0.2)
                  : const Color(0xFFF97316).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_fire_department_rounded,
              size: 26,
              color: hasReviewedToday ? Colors.white : const Color(0xFFF97316),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasReviewedToday
                      ? 'Bugungi streak saqlandi! 🔥'
                      : 'Streakni davom ettiring! ⏳',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: hasReviewedToday
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasReviewedToday
                      ? '${stats.streak} kun ketma-ket takrorladingiz. Ajoyib intizom!'
                      : 'Bugun hali so\'z takrorlanmadi. Streak uzilib qolmasin!',
                  style: TextStyle(
                    fontSize: 12,
                    color: hasReviewedToday
                        ? Colors.white.withValues(alpha: 0.9)
                        : (isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopStat({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtitle,
    required bool isDark,
  }) {
    return Container(
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextMuted
                        : AppColors.lightTextMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AppColors.darkTextMuted
                  : AppColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleWordsSection(StatsDataModel stats, bool isDark) {
    final troubleWords = stats.troubleWords;
    final displayList = _showAllTroubleWords
        ? troubleWords
        : troubleWords.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.destructive.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.destructive,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Ko\'p xato qilingan so\'zlar',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (troubleWords.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.destructive.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${troubleWords.length} ta',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.destructive,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            troubleWords.isEmpty
                ? 'Qayta takrorlashda e\'tibor qaratilishi lozim bo\'lgan so\'zlar'
                : 'Ushbu so\'zlarni takrorlashda ko\'proq xatolar kuzatilgan',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.darkTextMuted
                  : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 16),
          if (troubleWords.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 36,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ajoyib natija! Xatoliklar yo\'q 🎉',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Barcha o\'rganilgan so\'zlarni to\'g\'ri eslab qoldingiz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextMuted
                          : AppColors.lightTextMuted,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            ...displayList.map((item) => _buildTroubleWordTile(item, isDark)),
            if (troubleWords.length > 5) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(
                      () => _showAllTroubleWords = !_showAllTroubleWords,
                    );
                  },
                  icon: Icon(
                    _showAllTroubleWords
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                  label: Text(
                    _showAllTroubleWords
                        ? 'Kamroq ko\'rsatish'
                        : 'Barcha ${troubleWords.length} ta xato so\'zni ko\'rish',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTroubleWordTile(TroubleCardItem item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSecondary : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.volume_up_rounded, size: 20),
            color: isDark ? AppColors.brandDark : AppColors.brand,
            onPressed: () {
              TtsService.instance.speak(item.word);
            },
            tooltip: 'Talaffuzni eshitish',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.word,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (item.pronunciation != null &&
                        item.pronunciation!.trim().isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        item.pronunciation!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextMuted
                              : AppColors.lightTextMuted,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.translation,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.destructive.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${item.wrongReviews} ta xato',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.destructive,
                  ),
                ),
                Text(
                  '${item.errorRate.round()}% xatolik',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingStat({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AppColors.darkTextMuted
                  : AppColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow({
    required String label,
    required String sublabel,
    required int value,
    required int total,
    required Color barColor,
  }) {
    final pct = (value / (total > 0 ? total : 1)).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  sublabel,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
            Text(
              '$value ta (${(pct * 100).round()}%)',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: pct),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, animatedPct, _) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: animatedPct,
                minHeight: 8,
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            );
          },
        ),
      ],
    );
  }
}
