import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageNotifier extends StateNotifier<Locale> {
  LanguageNotifier() : super(const Locale('en')) {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('language') ?? 'ta';
    state = Locale(langCode);
  }

  Future<void> setLanguage(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', langCode);
    state = Locale(langCode);
  }

  bool get isTamil => state.languageCode == 'ta';
  bool get isEnglish => state.languageCode == 'en';
}

final languageProvider =
    StateNotifierProvider<LanguageNotifier, Locale>((ref) {
  return LanguageNotifier();
});