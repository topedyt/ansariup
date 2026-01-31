import 'package:flutter/material.dart';

// The "Ocean" Palette (Professional & Serious)
class AppTheme {
  final List<Color> bgGradient;
  final Color cardColor;
  final Color textColor;     // High contrast text
  final Color subTextColor;  // Medium contrast text
  final Color accentColor;   // For icons and buttons (Teal/Blue)
  final Color shadowColor;   // For Clay shadows

  AppTheme({
    required this.bgGradient,
    required this.cardColor,
    required this.textColor,
    required this.subTextColor,
    required this.accentColor,
    required this.shadowColor,
  });

  // The Factory: Returns Day or Night version
  static AppTheme getTheme(bool isDark) {
    if (isDark) {
      // 🌑 NIGHT: "Abyssal Zone"
      return AppTheme(
        bgGradient: [const Color(0xFF0F172A), const Color(0xFF1E293B)], // Slate-900 to Slate-800
        cardColor: const Color(0xFF1E293B), // Dark Slate
        textColor: const Color(0xFFF1F5F9), // Slate-100 (Off-white)
        subTextColor: const Color(0xFF94A3B8), // Slate-400
        accentColor: const Color(0xFF38BDF8),  // Sky Blue (Sharp contrast)
        shadowColor: const Color(0xFF020617),  // Almost Black
      );
    } else {
      // ☀️ DAY: "Coastal Mist"
      return AppTheme(
        bgGradient: [const Color(0xFFF0F9FF), const Color(0xFFE0F2FE)], // Very pale blue
        cardColor: const Color(0xFFFFFFFF), // Pure White
        textColor: const Color(0xFF0F172A), // Deep Navy (High readability)
        subTextColor: const Color(0xFF64748B), // Slate-500
        accentColor: const Color(0xFF0284C7),  // Deep Ocean Blue
        shadowColor: const Color(0xFFCBD5E1),  // Soft Grey-Blue
      );
    }
  }
}