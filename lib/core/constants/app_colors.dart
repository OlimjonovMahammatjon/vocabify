import 'package:flutter/material.dart';

class AppColors {
  // Navy Brand Palette
  static const Color brand = Color(0xFF1E2D4A); // #1e2d4a Primary
  static const Color brandDark = Color(
    0xFF4F75B3,
  ); // Light brand for dark theme

  // Accents & Alerts
  static const Color accent = Color(0xFFF59E0B); // Amber accent
  static const Color success = Color(0xFF10B981); // Emerald
  static const Color warning = Color(0xFFF97316); // Orange
  static const Color destructive = Color(0xFFEF4444); // Rose red

  // Light Theme
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightText = Color(0xFF0F172A);
  static const Color lightTextMuted = Color(0xFF64748B);
  static const Color lightSecondary = Color(0xFFF1F5F9);

  // Dark Theme
  static const Color darkBg = Color(0xFF0B111E);
  static const Color darkCard = Color(0xFF151E2E);
  static const Color darkBorder = Color(0xFF1E293B);
  static const Color darkText = Color(0xFFF1F5F9);
  static const Color darkTextMuted = Color(0xFF94A3B8);
  static const Color darkSecondary = Color(0xFF1E293B);

  // Deck color palettes
  static const Map<String, Color> deckColors = {
    'violet': Color(0xFF64748B),
    'amber': Color(0xFFF59E0B),
    'emerald': Color(0xFF10B981),
    'rose': Color(0xFFF43F5E),
    'sky': Color(0xFF0EA5E9),
  };

  static const Map<String, Color> deckBgLight = {
    'violet': Color(0xFFF8FAFC),
    'amber': Color(0xFFFFFBEB),
    'emerald': Color(0xFFECFDF5),
    'rose': Color(0xFFFFF1F2),
    'sky': Color(0xFFF0F9FF),
  };

  static const Map<String, Color> deckBgDark = {
    'violet': Color(0xFF1E293B),
    'amber': Color(0xFF2A1F0D),
    'emerald': Color(0xFF062A1F),
    'rose': Color(0xFF2E0D17),
    'sky': Color(0xFF08273D),
  };
}
