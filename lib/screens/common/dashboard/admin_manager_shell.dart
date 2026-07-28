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
import '../settings/settings_screen.dart';
import '../profile/profile_screen.dart';
import '../../../config/api_config.dart';

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
  bool _creationsOpen = false;
  bool _actionsOpen = false;

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
    }

    Widget navTile(int i) {
      return ListTile(
        leading: Icon(visibleItems[i].icon),
        title: Text(t.t(visibleItems[i].labelKey)),
        selected: _index == i,
        onTap: () => selectFromDrawer(i),
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

    Widget creationsTile() => Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: const PageStorageKey('drawer_creations'),
            initiallyExpanded: _creationsOpen || creationsSelected,
            onExpansionChanged: (open) => setState(() => _creationsOpen = open),
            leading: Icon(Icons.add_box_outlined, color: creationsSelected ? scheme.primary : null),
            title: Text(
              t.t('creations'),
              style: TextStyle(fontWeight: FontWeight.w600, color: creationsSelected ? scheme.primary : null),
            ),
            children: [for (final i in creationsIdx) navTile(i)],
          ),
        );

    Widget actionsTile() => Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: const PageStorageKey('drawer_actions'),
            initiallyExpanded: _actionsOpen || actionsSelected,
            onExpansionChanged: (open) => setState(() => _actionsOpen = open),
            leading: Icon(Icons.bolt_outlined, color: actionsSelected ? scheme.primary : null),
            title: Text(
              t.t('actionsMenu'),
              style: TextStyle(fontWeight: FontWeight.w600, color: actionsSelected ? scheme.primary : null),
            ),
            children: [for (final i in actionsIdx) navTile(i)],
          ),
        );

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
        drawerRows.add(item.group == 'creations' ? creationsTile() : actionsTile());
      }
    }

    // Bottom NavigationBar always maps to the first four (always-visible)
    // entries; clamp so a drawer screen doesn't crash the indicator.
    final bottomNavSelected = _index < 4 ? _index : 0;

    return Scaffold(
      appBar: AppBar(title: Text(t.t(visibleItems[_index].labelKey))),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
              color: Theme.of(context).colorScheme.primary,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white24,
                    backgroundImage: user.profileImage != null
                        ? NetworkImage('${ApiConfig.imageBaseUrl}/${user.profileImage!}')
                        : null,
                    child: user.profileImage == null
                        ? Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(user.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(user.type.toUpperCase(), style: const TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ...drawerRows,
          ],
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