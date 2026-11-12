import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Lightweight GPU-friendly pulse skeleton effect (no ShaderMask or gradients).
class AppShimmer extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final Color? baseColor;
  final Color? highlightColor;
  final Duration duration;

  const AppShimmer({
    super.key,
    required this.child,
    this.enabled = true,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 950),
  });

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.45, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return RepaintBoundary(
      child: FadeTransition(
        opacity: _opacity,
        child: widget.child,
      ),
    );
  }
}

/// Basic rectangular/rounded skeleton placeholder
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final ShapeBorder? shape;
  final EdgeInsetsGeometry? margin;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.shape,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: shape != null
          ? ShapeDecoration(color: color, shape: shape!)
          : BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
    );
  }
}

/// Single line skeleton placeholder for text labels
class SkeletonLine extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const SkeletonLine({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = 6,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: width,
      height: height,
      borderRadius: borderRadius,
      margin: margin,
    );
  }
}

/// Circular skeleton placeholder for avatars and icons
class SkeletonCircle extends StatelessWidget {
  final double size;
  final EdgeInsetsGeometry? margin;

  const SkeletonCircle({super.key, this.size = 44, this.margin});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

    return Container(
      width: size,
      height: size,
      margin: margin,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Full screen skeleton for HomeScreen
class HomeScreenSkeleton extends StatelessWidget {
  const HomeScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;

    return AppShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Streak Hero Skeleton
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          SkeletonBox(width: 48, height: 48, borderRadius: 14),
                          SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonLine(width: 70, height: 13),
                              SizedBox(height: 6),
                              SkeletonLine(width: 100, height: 22),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SkeletonLine(width: 40, height: 24),
                          SizedBox(height: 6),
                          SkeletonLine(width: 90, height: 13),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonLine(width: 90, height: 13),
                      SkeletonLine(width: 45, height: 13),
                    ],
                  ),
                  SizedBox(height: 8),
                  SkeletonBox(height: 10, borderRadius: 8),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Action buttons skeleton
            const Row(
              children: [
                Expanded(child: SkeletonBox(height: 90, borderRadius: 20)),
                SizedBox(width: 12),
                Expanded(child: SkeletonBox(height: 90, borderRadius: 20)),
              ],
            ),
            const SizedBox(height: 16),

            // 3. Mini stats 2x2 grid skeleton
            const Row(
              children: [
                Expanded(child: SkeletonBox(height: 64, borderRadius: 16)),
                SizedBox(width: 10),
                Expanded(child: SkeletonBox(height: 64, borderRadius: 16)),
              ],
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                Expanded(child: SkeletonBox(height: 64, borderRadius: 16)),
                SizedBox(width: 10),
                Expanded(child: SkeletonBox(height: 64, borderRadius: 16)),
              ],
            ),
            const SizedBox(height: 18),

            // 4. Decks Preview Card skeleton
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonLine(width: 110, height: 18),
                          SizedBox(height: 6),
                          SkeletonLine(width: 150, height: 12),
                        ],
                      ),
                      SkeletonBox(width: 70, height: 32, borderRadius: 12),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(
                    3,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSecondary
                              : AppColors.lightSecondary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Row(
                          children: [
                            SkeletonBox(
                              width: 44,
                              height: 44,
                              borderRadius: 12,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SkeletonLine(width: 130, height: 15),
                                  SizedBox(height: 6),
                                  SkeletonLine(width: 60, height: 12),
                                ],
                              ),
                            ),
                            SkeletonBox(width: 18, height: 18, borderRadius: 6),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full screen skeleton for DecksScreen
class DecksScreenSkeleton extends StatelessWidget {
  const DecksScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;

    return AppShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            children: [
              SkeletonBox(width: 52, height: 52, borderRadius: 14),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonLine(width: 140, height: 16),
                    SizedBox(height: 8),
                    SkeletonLine(width: 70, height: 12),
                  ],
                ),
              ),
              SkeletonBox(width: 32, height: 32, borderRadius: 10),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full screen skeleton for DeckDetailScreen
class DeckDetailScreenSkeleton extends StatelessWidget {
  const DeckDetailScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;

    return AppShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Column(
                children: [
                  Row(
                    children: [
                      SkeletonBox(width: 54, height: 54, borderRadius: 16),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLine(width: 150, height: 18),
                            SizedBox(height: 6),
                            SkeletonLine(width: 90, height: 13),
                          ],
                        ),
                      ),
                      SkeletonBox(width: 34, height: 34, borderRadius: 10),
                    ],
                  ),
                  SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      SkeletonBox(width: 70, height: 36, borderRadius: 10),
                      SkeletonBox(width: 70, height: 36, borderRadius: 10),
                      SkeletonBox(width: 70, height: 36, borderRadius: 10),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Action buttons
            const Row(
              children: [
                Expanded(child: SkeletonBox(height: 52, borderRadius: 16)),
                SizedBox(width: 10),
                Expanded(child: SkeletonBox(height: 52, borderRadius: 16)),
              ],
            ),
            const SizedBox(height: 14),

            // Search bar
            const SkeletonBox(height: 48, borderRadius: 14),
            const SizedBox(height: 18),

            // Words header
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SkeletonLine(width: 120, height: 16),
                SkeletonLine(width: 60, height: 13),
              ],
            ),
            const SizedBox(height: 12),

            // Words items
            ...List.generate(
              5,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
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
          ],
        ),
      ),
    );
  }
}

/// Full screen skeleton for StatsScreen
class StatsScreenSkeleton extends StatelessWidget {
  const StatsScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;

    return AppShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Streak banner
            Container(
              height: 120,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(height: 14),

            // 2x2 Top stats
            const Row(
              children: [
                Expanded(child: SkeletonBox(height: 94, borderRadius: 20)),
                SizedBox(width: 10),
                Expanded(child: SkeletonBox(height: 94, borderRadius: 20)),
              ],
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                Expanded(child: SkeletonBox(height: 94, borderRadius: 20)),
                SizedBox(width: 10),
                Expanded(child: SkeletonBox(height: 94, borderRadius: 20)),
              ],
            ),
            const SizedBox(height: 16),

            // Daily goal card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SkeletonLine(width: 120, height: 16),
                      SkeletonLine(width: 60, height: 16),
                    ],
                  ),
                  SizedBox(height: 14),
                  SkeletonBox(height: 12, borderRadius: 8),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Chart skeleton
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonLine(width: 160, height: 16),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildBar(40),
                      _buildBar(80),
                      _buildBar(130),
                      _buildBar(60),
                      _buildBar(100),
                      _buildBar(140),
                      _buildBar(90),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Trouble words skeleton
            Container(
              height: 120,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildBar(double height) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SkeletonBox(width: 24, height: height, borderRadius: 6),
        const SizedBox(height: 6),
        const SkeletonLine(width: 20, height: 10),
      ],
    );
  }
}
