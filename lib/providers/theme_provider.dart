import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'aj_theme_mode';

/// Maps the backend's `theme` string ('light' | 'dark') to a [ThemeMode] and
/// back. Persists locally so the choice survives app restarts even before
/// the profile call round-trips.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light) {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefsKey);
    if (value == 'dark') {
      state = ThemeMode.dark;
    } else if (value == 'light') {
      state = ThemeMode.light;
    }
  }

  /// Accepts the backend's raw 'light' / 'dark' string.
  Future<void> setThemeString(String value) async {
    state = value == 'dark' ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, value == 'dark' ? 'dark' : 'light');
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
