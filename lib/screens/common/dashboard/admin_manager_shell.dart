import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../l10n/app_localizations.dart';
import 'admin_dashboard_screen.dart';
import '../../admin/users/users_screen.dart';
import '../../admin/products/products_screen.dart';
import '../../admin/retailers/retailers_screen.dart';
import '../../admin/give_stock/give_stock_screen.dart';
import '../../admin/return_stock/return_stock_screen.dart';
import '../../admin/cash_payment/cash_payment_screen.dart';
import '../../admin/bills/bills_module_screen.dart';
import '../../admin/reports/reports_screen.dart';
import '../../admin/raw_materials/raw_materials_screen.dart';
import '../../admin/expenses/expenses_screen.dart';
import '../../admin/retailer_loans/retailer_loans_screen.dart';
import '../../admin/company/company_screen.dart';
import '../../admin/notifications/notifications_screen.dart';
import '../../admin/notifications/password_reset_requests_screen.dart';
import '../settings/settings_screen.dart';
import '../profile/profile_screen.dart';
import '../../../config/api_config.dart';
import '../../../services/notification_api_service.dart';

class AdminManagerShell extends ConsumerStatefulWidget {
  const AdminManagerShell({super.key});

  @override
  ConsumerState<AdminManagerShell> createState() => _AdminManagerShellState();
}

class _NavItem {
  final String labelKey; // key into AppLocalizations
  final IconData icon;
  final IconData? selectedIcon;
  final Widget Function() builder;
  final bool adminOnly;
  final String? group; // null = flat item, else 'creations' | 'actions'
  final bool inBottomNav; // shown in the bottom NavigationBar instead of the drawer
  const _NavItem(
    this.labelKey,
    this.icon,
    this.builder, {
    this.selectedIcon,
    this.adminOnly = false,
    this.group,
    this.inBottomNav = false,
  });
}

class _AdminManagerShellState extends ConsumerState<AdminManagerShell> {
  int _index = 0;
  bool _creationsOpen = true;
  bool _actionsOpen = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshUnreadCount());
  }

  /// Admin-only endpoint - silently no-ops (leaves the badge at 0) for
  /// managers/retailers, who never see the Notifications drawer item anyway.
  Future<void> _refreshUnreadCount() async {
    final user = ref.read(authProvider).user;
    if (user == null || !user.isAdmin) return;
    try {
      final count = await NotificationApiService.unreadCount();
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {}
  }

  // The first four entries are always visible and drive the bottom
  // NavigationBar (Dashboard, Reports, Profile, Settings), matching their
  // fixed 0-3 positions since none of them are adminOnly-filtered out.
  // Everything after that is reached from the drawer: Creations (Users,
  // Retailers, Products, Raw Materials, Retailer Loans, Company Setup),
  // Actions (Give/Return/Cash/Bill), then Expenses.
  late final List<_NavItem> _items = [
    _NavItem('dashboard', Icons.dashboard_outlined, () => const AdminDashboardScreen(),
        selectedIcon: Icons.dashboard, inBottomNav: true),
    _NavItem('reports', Icons.bar_chart_outlined, () => const ReportsScreen(),
        selectedIcon: Icons.bar_chart, inBottomNav: true),
    _NavItem('profile', Icons.person_outline, () => const ProfileScreen(),
        selectedIcon: Icons.person, inBottomNav: true),
    _NavItem('settings', Icons.settings_outlined, () => const SettingsScreen(),
        selectedIcon: Icons.settings, inBottomNav: true),
    _NavItem('users', Icons.people, () => const UsersScreen(), adminOnly: true, group: 'creations'),
    _NavItem('retailers', Icons.store, () => const RetailersScreen(), group: 'creations'),
    _NavItem('products', Icons.icecream, () => const ProductsScreen(), group: 'creations'),
    _NavItem('rawMaterials', Icons.category, () => const RawMaterialsScreen(), group: 'creations'),
    _NavItem('retailerLoans', Icons.account_balance_wallet_outlined, () => const RetailerLoansScreen(), group: 'creations'),
    _NavItem('companySetup', Icons.business, () => const CompanyScreen(), adminOnly: true, group: 'creations'),
    _NavItem('giveStock', Icons.arrow_upward, () => const GiveStockScreen(), group: 'actions'),
    _NavItem('returnStock', Icons.arrow_downward, () => const ReturnStockScreen(), group: 'actions'),
    _NavItem('cashPayment', Icons.currency_rupee, () => const CashPaymentScreen(), group: 'actions'),
    _NavItem('billGenerate', Icons.receipt_long, () => const BillsModuleScreen(), group: 'actions'),
    _NavItem('expenses', Icons.shopping_bag_outlined, () => const ExpensesScreen()),
    _NavItem('notifications', Icons.notifications_outlined, () => const NotificationsScreen(), adminOnly: true),
    _NavItem('passwordResetRequests', Icons.lock_reset, () => const PasswordResetRequestsScreen(), adminOnly: true),
  ];

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authProvider).user;
    // During logout this widget can get one more rebuild in the same frame
    // as the auth user being cleared, just before the root router swaps
    // the whole tree out for the login screen. Render nothing for that
    // instant rather than crashing on a null check.
    if (authUser == null) {
      return const Scaffold(body: SizedBox.shrink());
    }
    final user = authUser;
    final visibleItems = _items.where((i) => !i.adminOnly || user.isAdmin).toList();
    if (_index >= visibleItems.length) _index = 0;

    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    void select(int i) => setState(() => _index = i);

    void selectFromDrawer(int i) {
      select(i);
      Navigator.pop(context);
      _refreshUnreadCount();
    }

    Widget navTile(int i) {
      final selected = _index == i;
      final isNotifications = visibleItems[i].labelKey == 'notifications';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: selected ? Colors.white.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => selectFromDrawer(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  if (selected)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Icon(visibleItems[i].selectedIcon ?? visibleItems[i].icon, size: 18, color: scheme.primary),
                    )
                  else
                    Icon(visibleItems[i].icon, size: 20, color: Colors.white.withValues(alpha: 0.9)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      t.t(visibleItems[i].labelKey),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                  if (isNotifications && _unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _unreadCount > 99 ? '99+' : '$_unreadCount',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Group header row: "CREATIONS" / "ACTIONS" label + expand/collapse
    // chevron, white text on the gradient background.
    Widget groupHeader({required String label, required bool expanded, required VoidCallback onTap}) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Icon(
                expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ],
          ),
        ),
      );
    }

    // Indices (into visibleItems) belonging to each collapsible group.
    final creationsIdx = <int>[];
    final actionsIdx = <int>[];
    for (var i = 0; i < visibleItems.length; i++) {
      if (visibleItems[i].group == 'creations') creationsIdx.add(i);
      if (visibleItems[i].group == 'actions') actionsIdx.add(i);
    }
    final creationsSelected = creationsIdx.contains(_index);
    final actionsSelected = actionsIdx.contains(_index);

    Widget creationsSection() {
      final expanded = _creationsOpen || creationsSelected;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          groupHeader(
            label: t.t('creations'),
            expanded: expanded,
            onTap: () => setState(() => _creationsOpen = !expanded),
          ),
          if (expanded) for (final i in creationsIdx) navTile(i),
        ],
      );
    }

    Widget actionsSection() {
      final expanded = _actionsOpen || actionsSelected;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          groupHeader(
            label: t.t('actionsMenu'),
            expanded: expanded,
            onTap: () => setState(() => _actionsOpen = !expanded),
          ),
          if (expanded) for (final i in actionsIdx) navTile(i),
        ],
      );
    }

    // Walk the list in order, skipping bottom-nav items (shown below
    // instead), rendering other flat rows as plain tiles, and swapping in
    // each group's ExpansionTile the first time one of its items appears.
    final renderedGroups = <String>{};
    final drawerRows = <Widget>[];
    for (var i = 0; i < visibleItems.length; i++) {
      final item = visibleItems[i];
      if (item.inBottomNav) continue;
      if (item.group == null) {
        drawerRows.add(navTile(i));
      } else if (renderedGroups.add(item.group!)) {
        if (item.group == 'actions') {
          drawerRows.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: Colors.white.withValues(alpha: 0.25), height: 1, thickness: 1),
            ),
          );
        }
        drawerRows.add(item.group == 'creations' ? creationsSection() : actionsSection());
      }
    }

    // Bottom NavigationBar always maps to the first four (always-visible)
    // entries; clamp so a drawer screen doesn't crash the indicator.
    final bottomNavSelected = _index < 4 ? _index : 0;

    return Scaffold(
      appBar: _index == 0 ? null : AppBar(title: Text(t.t(visibleItems[_index].labelKey))),
      onDrawerChanged: (isOpened) {
        if (isOpened) _refreshUnreadCount();
      },
      drawer: Drawer(
        width: MediaQuery.of(context).size.width * 0.82,
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF13245C), Color(0xFF3B6FE0)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.white24,
                        backgroundImage: user.profileImage != null
                            ? NetworkImage('${ApiConfig.imageBaseUrl}/${user.profileImage!}')
                            : null,
                        child: user.profileImage == null
                            ? Text(
                                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(user.name,
                                style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(
                              user.type.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: drawerRows,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        final settingsIdx = visibleItems.indexWhere((i) => i.labelKey == 'settings');
                        if (settingsIdx != -1) selectFromDrawer(settingsIdx);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.shield_outlined, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('v 1.0.0',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
                                  Text(t.t('appTitle'),
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.7)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: visibleItems[_index].builder(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: bottomNavSelected,
        onDestinationSelected: select,
        destinations: [
          for (var i = 0; i < 4; i++)
            NavigationDestination(
              icon: Icon(visibleItems[i].icon),
              selectedIcon: Icon(visibleItems[i].selectedIcon ?? visibleItems[i].icon),
              label: t.t(visibleItems[i].labelKey),
            ),
        ],
      ),
    );
  }
}