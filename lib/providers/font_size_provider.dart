import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'aj_font_size';

/// Maps the backend's `font_size` string ('S' | 'M' | 'L' | 'XL') to a text
/// scale factor applied app-wide via a [MediaQuery] override in main.dart.
const Map<String, double> fontSizeScale = {
  'S': 0.85,
  'M': 1.0,
  'L': 1.15,
  'XL': 1.3,
};

class FontSizeNotifier extends StateNotifier<String> {
  FontSizeNotifier() : super('M') {
    _restore();
  }

  double get scale => fontSizeScale[state] ?? 1.0;

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefsKey);
    if (value != null && fontSizeScale.containsKey(value)) {
      state = value;
    }
  }

  Future<void> setFontSize(String value) async {
    if (!fontSizeScale.containsKey(value)) return;
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, value);
  }
}

final fontSizeProvider = StateNotifierProvider<FontSizeNotifier, String>((ref) {
  return FontSizeNotifier();
});
