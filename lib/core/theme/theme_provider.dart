import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';

// 1. Theme Mode Controller (Day vs Night)
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system);

  void toggleTheme() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  }
  
  void setSystem() {
    state = ThemeMode.system;
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

// 2. Palette Provider (Returns the Colors)
final appThemeProvider = Provider<AppTheme>((ref) {
  final mode = ref.watch(themeModeProvider);
  
  // Calculate actual brightness
  var brightness = SchedulerBinding.instance.platformDispatcher.platformBrightness;
  if (mode == ThemeMode.dark) brightness = Brightness.dark;
  if (mode == ThemeMode.light) brightness = Brightness.light;
  
  final isDark = brightness == Brightness.dark;

  // Return our single Ocean theme
  return AppTheme.getTheme(isDark);
});