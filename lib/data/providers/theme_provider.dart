import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeState {
  final Color primaryColor;
  final bool isDark;

  ThemeState({
    this.primaryColor = const Color(0xFF1E4D78),
    this.isDark = false,
  });

  ThemeState copyWith({
    Color? primaryColor,
    bool? isDark,
  }) {
    return ThemeState(
      primaryColor: primaryColor ?? this.primaryColor,
      isDark: isDark ?? this.isDark,
    );
  }
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier() : super(ThemeState()) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('theme_color');
    final isDark = prefs.getBool('theme_dark') ?? false;
    if (colorValue != null) {
      state = ThemeState(
        primaryColor: Color(colorValue),
        isDark: isDark,
      );
    } else {
      state = ThemeState(isDark: isDark);
    }
  }

  Future<void> setColor(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_color', color.value);
    state = state.copyWith(primaryColor: color);
  }

  Future<void> toggleDark(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('theme_dark', isDark);
    state = state.copyWith(isDark: isDark);
  }
}

final themeProvider =
    StateNotifierProvider<ThemeNotifier, ThemeState>(
        (ref) => ThemeNotifier());