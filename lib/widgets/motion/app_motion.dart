import 'dart:async';

import 'package:flutter/material.dart';

/// Tactile micro-scale wrapper on pointer down/up that preserves InkWell taps.
class PressScale extends StatefulWidget {
  final Widget child;
  final double pressedScale;
  final Duration duration;

  const PressScale({
    super.key,
    required this.child,
    this.pressedScale = 0.975,
    this.duration = const Duration(milliseconds: 110),
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed != value && mounted) {
      setState(() => _isPressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _isPressed ? widget.pressedScale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Lightweight one-shot fade + subtle upward slide entrance animation.
class StaggeredEntrance extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration duration;
  final double slideOffsetY;

  const StaggeredEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 280),
    this.slideOffsetY = 0.035,
  });

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _fade = curved;
    _slide = Tween<Offset>(
      begin: Offset(0, widget.slideOffsetY),
      end: Offset.zero,
    ).animate(curved);

    final delayMs = (widget.index.clamp(0, 6)) * 35;
    if (delayMs == 0) {
      _controller.forward();
    } else {
      _delayTimer = Timer(Duration(milliseconds: delayMs), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Smoothly animates an integer value from 0 (or previous value) to [value].
class AnimatedCountText extends StatelessWidget {
  final int value;
  final String suffix;
  final String prefix;
  final TextStyle? style;
  final Duration duration;

  const AnimatedCountText({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.duration = const Duration(milliseconds: 520),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return Text('$prefix$animatedValue$suffix', style: style);
      },
    );
  }
}

