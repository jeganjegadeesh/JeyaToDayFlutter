import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jeyatoday/l10n/app_localizations.dart';
import '../../../core/constants/app_assets.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/providers/language_provider.dart';
import '../../widgets/common/app_layout.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    final locale = ref.watch(languageProvider);
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1200;

    return AppLayout(
      title: l10n.settings,
      selectedIndex: 6,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isDesktop ? 32 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme Section
            _SectionCard(
              title: l10n.theme,
              icon: Icons.palette_outlined,
              color: themeState.primaryColor,
              children: [
                // Dark Mode Toggle
                SwitchListTile(
                  title: Text(
                    'Dark Mode',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'Switch between light and dark theme',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[500]),
                  ),
                  value: themeState.isDark,
                  activeColor: themeState.primaryColor,
                  onChanged: (val) {
                    ref
                        .read(themeProvider.notifier)
                        .toggleDark(val);
                  },
                ),
                const Divider(),

                // Color Picker
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.chooseThemeColor,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Quick Color Options
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _themeColors.map((color) {
                          final isSelected =
                              themeState.primaryColor.value ==
                                  color.value;
                          return GestureDetector(
                            onTap: () => ref
                                .read(themeProvider.notifier)
                                .setColor(color),
                            child: AnimatedContainer(
                              duration: const Duration(
                                  milliseconds: 200),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius:
                                    BorderRadius.circular(12),
                                border: isSelected
                                    ? Border.all(
                                        color: Colors.white,
                                        width: 3)
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color
                                              .withOpacity(0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        )
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      color: Colors.white,
                                      size: 20)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Custom Color Picker Button
                      OutlinedButton.icon(
                        onPressed: () =>
                            _showColorPicker(context, ref,
                                themeState.primaryColor),
                        icon: Icon(Icons.color_lens,
                            color:
                                themeState.primaryColor),
                        label: Text(
                          'Custom Color',
                          style: GoogleFonts.poppins(
                              color:
                                  themeState.primaryColor),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color:
                                  themeState.primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Language Section
            _SectionCard(
              title: l10n.language,
              icon: Icons.language_outlined,
              color: const Color(0xFF27AE60),
              children: [
                // English
                RadioListTile<String>(
                  title: Text(
                    'English',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'Use app in English',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[500]),
                  ),
                  value: 'en',
                  groupValue: locale.languageCode,
                  activeColor: themeState.primaryColor,
                  onChanged: (val) {
                    if (val != null) {
                      ref
                          .read(languageProvider.notifier)
                          .setLanguage(val);
                    }
                  },
                ),
                const Divider(height: 1),

                // Tamil
                RadioListTile<String>(
                  title: Text(
                    'தமிழ் (Tamil)',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'பயன்பாட்டை தமிழில் பயன்படுத்தவும்',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[500]),
                  ),
                  value: 'ta',
                  groupValue: locale.languageCode,
                  activeColor: themeState.primaryColor,
                  onChanged: (val) {
                    if (val != null) {
                      ref
                          .read(languageProvider.notifier)
                          .setLanguage(val);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // App Info Section
            _SectionCard(
              title: 'App Info',
              icon: Icons.info_outline,
              color: const Color(0xFF8E44AD),
              children: [
                ListTile(
                  leading: Image.asset(
                    AppAssets.logo,
                    color: const Color(0xFF8E44AD),
                  ),
                  // const Icon(Icons.icecream,
                  //     color: Color(0xFF8E44AD)),
                  title: Text(
                    'Aj',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Ice Cream Distribution System',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[500]),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E44AD)
                          .withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: Text(
                      'v1.0.0',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF8E44AD),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Predefined theme colors
  static const List<Color> _themeColors = [
    Color(0xFF1E4D78), // Default Blue
    Color(0xFF2E75B6), // Light Blue
    Color(0xFF27AE60), // Green
    Color(0xFFE67E22), // Orange
    Color(0xFFE74C3C), // Red
    Color(0xFF8E44AD), // Purple
    Color(0xFF2C3E50), // Dark Blue
    Color(0xFF16A085), // Teal
    Color(0xFFC0392B), // Dark Red
    Color(0xFF1ABC9C), // Emerald
    Color(0xFFD35400), // Dark Orange
    Color(0xFF6C5CE7), // Violet
  ];

  void _showColorPicker(
      BuildContext context, WidgetRef ref, Color current) {
    Color pickedColor = current;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Pick a Color',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: ColorPicker(
            color: pickedColor,
            onColorChanged: (color) {
              pickedColor = color;
            },
            width: 40,
            height: 40,
            borderRadius: 10,
            spacing: 5,
            runSpacing: 5,
            wheelDiameter: 200,
            heading: Text(
              'Select color',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            subheading: Text(
              'Select color shade',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            wheelSubheading: Text(
              'Selected color and its shades',
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            showMaterialName: true,
            showColorName: true,
            showColorCode: true,
            copyPasteBehavior:
                const ColorPickerCopyPasteBehavior(
              longPressMenu: true,
            ),
            materialNameTextStyle:
                GoogleFonts.poppins(fontSize: 11),
            colorNameTextStyle:
                GoogleFonts.poppins(fontSize: 11),
            colorCodeTextStyle:
                GoogleFonts.poppins(fontSize: 11),
            pickersEnabled: const <ColorPickerType, bool>{
              ColorPickerType.both: false,
              ColorPickerType.primary: true,
              ColorPickerType.accent: true,
              ColorPickerType.bw: false,
              ColorPickerType.custom: false,
              ColorPickerType.wheel: true,
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(themeProvider.notifier)
                  .setColor(pickedColor);
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
                16, 16, 16, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}