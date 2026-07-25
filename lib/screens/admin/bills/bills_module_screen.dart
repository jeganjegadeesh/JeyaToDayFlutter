import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'bill_generate_screen.dart';
import 'bill_history_screen.dart';

const _kAccentBlue = Color(0xFF3B82F6);

class BillsModuleScreen extends StatelessWidget {
  const BillsModuleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            TabBar(
              indicatorColor: _kAccentBlue,
              indicatorWeight: 3,
              labelColor: _kAccentBlue,
              unselectedLabelColor: scheme.onSurfaceVariant,
              tabs: [
                Tab(text: t.t('newBill'), icon: const Icon(Icons.add_card_outlined)),
                Tab(text: t.t('history'), icon: const Icon(Icons.history)),
              ],
            ),
            const Expanded(
              child: TabBarView(children: [
                BillGenerateScreen(),
                BillHistoryScreen(),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}