import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import 'sales_report_screen.dart';
import 'stock_report_screen.dart';
import 'cash_report_screen.dart';

const _kAccentBlue = Color(0xFF3B82F6);
const _kAccentGreen = Color(0xFF10B981);
const _kAccentAmber = Color(0xFFF59E0B);

/// Reports hub: a menu that fans out into the three separate report
/// screens (Sales / Stock / Cash), each with its own AppBar and back button.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(t.t('reports'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 20),
            child: Text(
              t.t('reports'),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          _ReportMenuTile(
            icon: Icons.trending_up,
            color: _kAccentBlue,
            title: t.t('salesReports'),
            subtitle: t.t('salesReportsDesc'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SalesReportScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ReportMenuTile(
            icon: Icons.inventory_2_outlined,
            color: _kAccentGreen,
            title: t.t('stockReports'),
            subtitle: t.t('stockReportsDesc'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StockReportScreen()),
            ),
          ),
          const SizedBox(height: 12),
          _ReportMenuTile(
            icon: Icons.account_balance,
            color: _kAccentAmber,
            title: t.t('cashReports'),
            subtitle: t.t('cashReportsDesc'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CashReportScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportMenuTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ReportMenuTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: scheme.shadow.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: scheme.onSurface)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}