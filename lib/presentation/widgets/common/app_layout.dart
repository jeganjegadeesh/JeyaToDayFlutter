import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/providers/theme_provider.dart';
import 'app_header.dart';
import 'app_sidebar.dart';

class AppLayout extends ConsumerWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final int selectedIndex;
  final bool showBack;
  final Widget? floatingActionButton;

  const AppLayout({
    super.key,
    required this.title,
    required this.child,
    required this.selectedIndex,
    this.actions,
    this.showBack = false,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= AppConstants.desktopBreakpoint;
    final isDark = ref.watch(themeProvider).isDark;
    final bgColor = isDark
        ? const Color(0xFF121212)
        : const Color(0xFFF5F7FA);

    // Force portrait on mobile
    if (!isDesktop) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }

    if (isDesktop) {
      // Desktop Layout — Sidebar + Content
      return Scaffold(
        backgroundColor: bgColor,
        body: Row(
          children: [
            AppSidebar(selectedIndex: selectedIndex),
            Expanded(
              child: Column(
                children: [
                  AppHeader(
                    title: title,
                    actions: actions,
                    showBack: showBack,
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: floatingActionButton,
      );
    }

    // Mobile Layout — AppBar with Drawer
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppHeader(
        title: title,
        actions: actions,
        showBack: showBack,
        showDrawerIcon: true,
      ),
      drawer: Drawer(
        child: AppSidebar(selectedIndex: selectedIndex),
      ),
      body: child,
      floatingActionButton: floatingActionButton,
    );
  }
}