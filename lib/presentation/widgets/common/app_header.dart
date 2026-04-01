import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../screens/auth/login_screen.dart';

class AppHeader extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;
  final bool showDrawerIcon;

  const AppHeader({
    super.key,
    required this.title,
    this.actions,
    this.showBack = false,
    this.showDrawerIcon = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = ref.watch(themeProvider).primaryColor;
    final isDark = ref.watch(themeProvider).isDark;

    return AppBar(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: showBack || showDrawerIcon,
      leading: showDrawerIcon
          ? Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            )
          : showBack
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                )
              : null,
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      actions: [
        if (actions != null) ...actions!,
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white),
          tooltip: 'Logout',
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('Logout', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                content: Text('Are you sure you want to logout?', style: GoogleFonts.poppins()),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red, foregroundColor: Colors.white),
                    child: const Text('Logout'),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            }
          },
        ),
      ],
    );
  }
}