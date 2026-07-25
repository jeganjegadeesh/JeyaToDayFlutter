import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/font_size_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../providers/theme_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/auth_service.dart';
import '../../../services/api_service.dart';
import '../../../widgets/dialogs.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late String _theme;
  late String _language;
  late String _fontSize;

  @override
  void initState() {
    super.initState();
    final u = ref.read(authProvider).user!;
    _theme = u.theme;
    _language = u.language;
    _fontSize = u.fontSize;
  }

  /// Persists [key]/[value] to the backend profile. Any failure just shows a
  /// snackbar — the local (already-applied) UI change is not rolled back, so
  /// the app stays responsive even if the network call fails.
  Future<void> _persist(String key, String value) async {
    try {
      final user = await AuthService.updateProfile({key: value});
      if (mounted) ref.read(authProvider).updateUser(user);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _updateTheme(String value) async {
    setState(() => _theme = value);
    // Apply immediately across the whole app...
    await ref.read(themeModeProvider.notifier).setThemeString(value);
    // ...then persist it to the backend.
    await _persist('theme', value);
  }

  Future<void> _updateLanguage(String value) async {
    setState(() => _language = value);
    await ref.read(localeProvider.notifier).setLocale(value);
    await _persist('language', value);
  }

  Future<void> _updateFontSize(String value) async {
    setState(() => _fontSize = value);
    await ref.read(fontSizeProvider.notifier).setFontSize(value);
    await _persist('font_size', value);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Scaffold(
      body: ListView(
        children: [
          ListTile(title: Text(t.t('theme')), dense: true),
          RadioListTile(
            title: Text(t.t('light')),
            value: 'light',
            groupValue: _theme,
            onChanged: (v) => _updateTheme(v!),
          ),
          RadioListTile(
            title: Text(t.t('dark')),
            value: 'dark',
            groupValue: _theme,
            onChanged: (v) => _updateTheme(v!),
          ),
          const Divider(),
          ListTile(title: Text(t.t('language')), dense: true),
          RadioListTile(
            title: Text(t.t('tamil')),
            value: 'ta',
            groupValue: _language,
            onChanged: (v) => _updateLanguage(v!),
          ),
          RadioListTile(
            title: Text(t.t('english')),
            value: 'en',
            groupValue: _language,
            onChanged: (v) => _updateLanguage(v!),
          ),
          const Divider(),
          ListTile(title: Text(t.t('fontSize')), dense: true),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: ['S', 'M', 'L', 'XL']
                  .map((s) => ChoiceChip(
                        label: Text(s),
                        selected: _fontSize == s,
                        onSelected: (_) => _updateFontSize(s),
                      ))
                  .toList(),
            ),
          ),
          const Divider(),
          ListTile(
            title: Text(t.t('appInfo')),
            subtitle: const Text('AJ Project · Version 1.0.0'),
            dense: true,
          ),
        ],
      ),
    );
  }
}
