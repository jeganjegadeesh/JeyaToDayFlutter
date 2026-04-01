import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jeyatoday/l10n/app_localizations.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/utils/app_helpers.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/products/products_screen.dart';
import '../../screens/retailers/retailers_screen.dart';
import '../../screens/stock/stock_screen.dart';
import '../../screens/returns/returns_screen.dart';
import '../../screens/bills/bills_screen.dart';
import '../../screens/reports/reports_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/users/users_screen.dart';

class AppSidebar extends ConsumerWidget {
  final int selectedIndex;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final primary = ref.watch(themeProvider).primaryColor;
    final l10n = AppLocalizations.of(context)!;
    final isAdmin = user?.isAdmin ?? false;
    final isUser = user?.isUser ?? false;
    final isDark =
        ref.watch(themeProvider).isDark;

    // Menu items based on role
    final menuItems = _getMenuItems(l10n, isAdmin, isUser);

    return Container(
      width: 240,
      color: isDark
          ? const Color(0xFF1A1A2E)
          : primary,
      child: Column(
        children: [
          // Logo & App Name
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            decoration: const BoxDecoration(
              border: Border(
                bottom:
                    BorderSide(color: Colors.white12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                  child: Image.asset(
                    AppAssets.logo,
                    height: 25,
                    width: 25,
                    color: const Color(0xFF2E75B6),
                  ),
                  // Icon(
                  //   Icons.icecream,
                  //   color: primary,
                  //   size: 24,
                  // ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.appName,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Distribution',
                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                  vertical: 12),
              children: menuItems.map((item) {
                final isActive =
                    selectedIndex == item.index;
                return _buildMenuItem(
                  context: context,
                  item: item,
                  isActive: isActive,
                  primary: primary,
                  onTap: () =>
                      _navigate(context, item.index),
                );
              }).toList(),
            ),
          ),

          // User Info & Logout
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white12),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => _navigate(context, 7),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor:
                        Colors.white.withOpacity(0.2),
                    child: Text(
                      AppHelpers.getInitials(
                          user?.name ?? 'A'),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        _navigate(context, 7),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'User',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          overflow:
                              TextOverflow.ellipsis,
                        ),
                        Text(
                          user?.role ?? '',
                          style: GoogleFonts.poppins(
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final confirm =
                        await AppHelpers.showConfirm(
                      context,
                      title: l10n.logout,
                      message:
                          'Are you sure you want to logout?',
                      confirmText: l10n.logout,
                    );
                    if (confirm && context.mounted) {
                      await ref
                          .read(authProvider.notifier)
                          .logout();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const LoginScreen()),
                          (route) => false,
                        );
                      }
                    }
                  },
                  icon: const Icon(
                    Icons.logout,
                    color: Colors.white54,
                    size: 20,
                  ),
                  tooltip: l10n.logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_MenuItem> _getMenuItems(AppLocalizations l10n, bool isAdmin, bool isUser) {
  if (isAdmin || isUser) {
    return [
      _MenuItem(l10n.dashboard, Icons.dashboard_outlined, 0),
      _MenuItem(l10n.products, Icons.inventory_2_outlined, 1),
      _MenuItem(l10n.retailers, Icons.people_outlined, 2),
      _MenuItem(l10n.giveStock, Icons.local_shipping_outlined, 3),
      _MenuItem(l10n.returns, Icons.assignment_return_outlined, 4),
      _MenuItem(l10n.bills, Icons.receipt_long_outlined, 5),
      _MenuItem(l10n.reports, Icons.bar_chart_outlined, 6),
      _MenuItem(l10n.users, Icons.manage_accounts_outlined, 9),
      _MenuItem(l10n.settings, Icons.settings_outlined, 8),
    ];
  } else {
    return [
      _MenuItem(l10n.dashboard, Icons.dashboard_outlined, 0),
      _MenuItem(l10n.myStock, Icons.local_shipping_outlined, 3),
      _MenuItem(l10n.myReturns, Icons.assignment_return_outlined, 4),
      _MenuItem(l10n.myBills, Icons.receipt_long_outlined, 5),
      _MenuItem(l10n.settings, Icons.settings_outlined, 8),
    ];
  }
}

  Widget _buildMenuItem({
    required BuildContext context,
    required _MenuItem item,
    required bool isActive,
    required Color primary,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.white.withOpacity(0.2)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          item.icon,
          color: isActive
              ? Colors.white
              : Colors.white60,
          size: 22,
        ),
        title: Text(
          item.title,
          style: GoogleFonts.poppins(
            color: isActive
                ? Colors.white
                : Colors.white60,
            fontWeight: isActive
                ? FontWeight.w600
                : FontWeight.normal,
            fontSize: 13,
          ),
        ),
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, int index) {
    Widget screen;
    switch (index) {
      case 0:
        screen = const DashboardScreen();
        break;
      case 1:
        screen = const ProductsScreen();
        break;
      case 2:
        screen = const RetailersScreen();
        break;
      case 3:
        screen = const StockScreen();
        break;
      case 4:
        screen = const ReturnsScreen();
        break;
      case 5:
        screen = const BillsScreen();
        break;
      case 6:
        screen = const ReportsScreen();
        break;
      case 7:
        screen = const ProfileScreen();
        break;
      case 8:
        screen = const SettingsScreen();
        break;
      case 9:
        screen = const UsersScreen();
        break;
      default:
        screen = const DashboardScreen();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }
}

class _MenuItem {
  final String title;
  final IconData icon;
  final int index;

  _MenuItem(this.title, this.icon, this.index);
}