import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Language codes supported by the app. Keep in sync with the radio options
/// in SettingsScreen and with [AppUser.language] values sent by the backend.
const supportedLocaleCodes = ['en', 'ta'];

const _prefsKey = 'aj_locale_code';

/// Persists and exposes the app's current [Locale].
///
/// Read with `ref.watch(localeProvider)`.
/// Change with `ref.read(localeProvider.notifier).setLocale('ta')`.
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('ta')) {
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code != null && supportedLocaleCodes.contains(code)) {
      state = Locale(code);
    }
  }

  Future<void> setLocale(String code) async {
    if (!supportedLocaleCodes.contains(code)) return;
    state = Locale(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, code);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});
