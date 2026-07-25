import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../retailer/retailer_dashboard_screen.dart';
import '../../retailer/received_stock/received_stock_screen.dart';
import '../../retailer/returned_stock/returned_stock_screen.dart';
import '../../retailer/payments/payments_screen.dart';
import '../../retailer/bills/retailer_bills_screen.dart';
import '../../retailer/reports/retailer_reports_screen.dart';
import '../settings/settings_screen.dart';
import '../profile/profile_screen.dart';

class RetailerShell extends ConsumerStatefulWidget {
  const RetailerShell({super.key});

  @override
  ConsumerState<RetailerShell> createState() => _RetailerShellState();
}

class _RetailerShellState extends ConsumerState<RetailerShell> {
  int _index = 0;

  static const _labelKeys = ['dashboard', 'received', 'returned', 'paid', 'bills', 'reports'];
  static const _icons = [
    Icons.dashboard,
    Icons.move_to_inbox,
    Icons.undo,
    Icons.currency_rupee,
    Icons.receipt,
    Icons.bar_chart,
  ];

  final _screens = const [
    RetailerDashboardScreen(),
    ReceivedStockScreen(),
    ReturnedStockScreen(),
    PaymentsScreen(),
    RetailerBillsScreen(),
    RetailerReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user!;
    final t = context.l10n;

    return Scaffold(
      appBar: _index == 0
          ? AppBar(
              title: Text('Hi, ${user.name}'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                ),
                IconButton(
                  icon: const Icon(Icons.person),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                ),
              ],
            )
          : null,
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (int i = 0; i < _labelKeys.length; i++)
            NavigationDestination(icon: Icon(_icons[i]), label: t.t(_labelKeys[i])),
        ],
      ),
    );
  }
}
