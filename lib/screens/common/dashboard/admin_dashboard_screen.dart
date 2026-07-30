import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/report_service.dart';
import '../../../services/api_service.dart';
import '../../../widgets/dialogs.dart';
import '../../admin/give_stock/give_stock_screen.dart';
import '../../admin/return_stock/return_stock_screen.dart';
import '../../admin/cash_payment/cash_payment_screen.dart';
import '../../admin/bills/bills_module_screen.dart';
import '../../admin/bills/bill_history_screen.dart';
import '../../admin/reports/reports_screen.dart';

// Same brand palette used across the bills / reports screens so the
// dashboard reads as part of the same app rather than a bolt-on redesign.
const _kAccentBlue = Color(0xFF3B82F6);
const _kAmber = Color(0xFFF59E0B);
const _kGreen = Color(0xFF10B981);
const _kRed = Color(0xFFEF4444);

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  String _period = 'weekly';
  Map<String, dynamic>? _data;
  bool _loading = true;

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _data = await ReportService.dashboard(_period);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authProvider).user;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _header(context, t, user?.name ?? ''),
            const SizedBox(height: 24),
            Text(t.t('quickActions'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _quickAction(context, Icons.north_east, t.t('giveStock'), _kAccentBlue, const GiveStockScreen()),
                _quickAction(context, Icons.south_west, t.t('returnStock'), _kAmber, const ReturnStockScreen()),
                _quickAction(context, Icons.currency_rupee, t.t('cashPayment'), _kGreen, const CashPaymentScreen()),
                _quickAction(context, Icons.receipt_long_outlined, t.t('billGenerate'), _kAccentBlue, const BillsModuleScreen()),
              ],
            ),
            const SizedBox(height: 24),
            _salesAnalysisCard(context, t, scheme),
            const SizedBox(height: 16),
            if (_data != null) ...[
              _statCard(
                context,
                label: t.t('totalRetailers'),
                value: '${_data!['total_retailers'] ?? 0}',
                icon: Icons.storefront_outlined,
                color: _kAccentBlue,
              ),
              const SizedBox(height: 12),
              _statCard(
                context,
                label: t.t('billsThisMonth'),
                value: '${_data!['total_bills_this_month'] ?? 0}',
                icon: Icons.receipt_long_outlined,
                color: _kGreen,
              ),
              const SizedBox(height: 12),
              _statCard(
                context,
                label: t.t('pendingLoans'),
                value: _currency.format(double.tryParse('${_data!['pending_loans'] ?? 0}') ?? 0),
                icon: Icons.account_balance_wallet_outlined,
                color: _kRed,
              ),
            ],
            const SizedBox(height: 24),
            _recentTransactionsSection(context, t, scheme),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Greeting header: menu + notification icons, "Good Morning" + the
  // signed-in user's name, the app tagline, and the brand logo — mirrors
  // the light "Modern & Minimal" reference design.
  // ---------------------------------------------------------------------
  Widget _header(BuildContext context, AppLocalizations t, String userName) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => Scaffold.of(context).openDrawer(),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.menu, size: 26),
              ),
            ),
            const Spacer(),
            InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => showSnack(context, t.t('featureComingSoon')),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: scheme.shadow.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3)),
                  ],
                ),
                child: const Icon(Icons.notifications_none_rounded, size: 22),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${t.t('goodMorning')} 👋',
                    style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    userName.isNotEmpty ? userName : t.t('appTitle'),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    t.t('appTagline'),
                    style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Image.asset(
              'assets/logo.png',
              width: 76,
              height: 76,
              fit: BoxFit.contain,
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Sales Analysis card: weekly/monthly pill toggle + bar chart + today's
  // total with a % change chip, all inside one rounded surface.
  // ---------------------------------------------------------------------
  Widget _salesAnalysisCard(BuildContext context, AppLocalizations t, ColorScheme scheme) {
    final salesToday = double.tryParse('${_data?['total_sales_today'] ?? 0}') ?? 0;
    final changePercent = double.tryParse('${_data?['sales_change_percent'] ?? 0}') ?? 0;
    final isUp = changePercent >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: scheme.shadow.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  t.t('sales'),
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
              ),
              _periodToggle(scheme, t),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
          else
            _buildChart(t, scheme),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.t('totalSalesToday'),
                        style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(
                      _currency.format(salesToday),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (isUp ? _kGreen : _kRed).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isUp ? Icons.trending_up : Icons.trending_down, size: 15, color: isUp ? _kGreen : _kRed),
                    const SizedBox(width: 4),
                    Text(
                      '${isUp ? '+' : ''}${changePercent.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isUp ? _kGreen : _kRed),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _periodToggle(ColorScheme scheme, AppLocalizations t) {
    Widget seg(String value, String label) {
      final selected = _period == value;
      return GestureDetector(
        onTap: () {
          if (_period == value) return;
          setState(() => _period = value);
          _load();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? scheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: selected
                ? [BoxShadow(color: scheme.shadow.withValues(alpha: 0.10), blurRadius: 6, offset: const Offset(0, 2))]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? _kAccentBlue : scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg('weekly', t.t('weekly')),
          seg('monthly', t.t('monthly')),
        ],
      ),
    );
  }

  Widget _buildChart(AppLocalizations t, ColorScheme scheme) {
    final chart = (_data?['sales_chart'] as List?) ?? [];
    if (chart.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(t.t('noSalesData'), style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
      );
    }

    // Keep only the most recent 6 points so the bars stay wide and
    // legible, matching the reference design's Mon-Sat layout.
    final trimmed = chart.length > 6 ? chart.sublist(chart.length - 6) : chart;

    double maxSales = 0;
    final values = <double>[];
    final labels = <String>[];
    for (final row in trimmed) {
      final map = Map<String, dynamic>.from(row);
      final sales = double.tryParse('${map['sales'] ?? 0}') ?? 0;
      values.add(sales);
      if (sales > maxSales) maxSales = sales;
      labels.add(_periodLabel('${map['period'] ?? ''}'));
    }
    final maxY = maxSales <= 0 ? 10.0 : maxSales * 1.25;

    final bars = <BarChartGroupData>[];
    for (var i = 0; i < values.length; i++) {
      final isPeak = values[i] == maxSales && maxSales > 0;
      bars.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: values[i],
              width: 22,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: isPeak
                    ? [_kAccentBlue, const Color(0xFF6366F1)]
                    : [_kAccentBlue.withValues(alpha: 0.55), _kAccentBlue.withValues(alpha: 0.85)],
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxY,
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          barGroups: bars,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) => FlLine(color: scheme.outlineVariant.withValues(alpha: 0.3), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      labels[i],
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
                _currency.format(rod.toY),
                TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Turns a raw `period` value ("2026-07" or a YEARWEEK int like 202630)
  /// into a short, human label for the bar chart's x-axis.
  String _periodLabel(String period) {
    if (period.isEmpty) return '';
    if (period.contains('-')) {
      final parts = period.split('-');
      if (parts.length == 2) {
        final month = int.tryParse(parts[1]);
        if (month != null && month >= 1 && month <= 12) {
          const names = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          return names[month];
        }
      }
      return period;
    }
    // YEARWEEK format, e.g. 202630 -> week 30
    if (period.length >= 2) {
      final week = period.substring(period.length - 2);
      return 'W$week';
    }
    return period;
  }

  Widget _statCard(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: scheme.shadow.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 22),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Recent Transactions: header + "Generate Report" button, then a rounded
  // list card mirroring each bill's retailer, date and amount.
  // ---------------------------------------------------------------------
  Widget _recentTransactionsSection(BuildContext context, AppLocalizations t, ColorScheme scheme) {
    final transactions = (_data?['recent_transactions'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                t.t('recentTransactions'),
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
            ),
            OutlinedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              child: Text(t.t('generateReport'), style: const TextStyle(fontSize: 12.5)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading)
          const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))
        else if (transactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(16)),
            child: Text(t.t('noTransactionsYet'), style: TextStyle(color: scheme.onSurfaceVariant)),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: scheme.shadow.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              children: [
                for (var i = 0; i < transactions.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 68, color: scheme.outlineVariant.withValues(alpha: 0.4)),
                  _transactionTile(context, Map<String, dynamic>.from(transactions[i]), i, scheme),
                ],
              ],
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _transactionTile(BuildContext context, Map<String, dynamic> tx, int index, ColorScheme scheme) {
    final kind = '${tx['kind'] ?? 'sale'}'; // sale (neutral) | income (blue) | expense (red)
    final title = ((tx['title'] as String?)?.trim().isNotEmpty ?? false) ? tx['title'] as String : 'Transaction';
    final subtitle = (tx['subtitle'] as String?)?.trim();
    final amount = double.tryParse('${tx['amount'] ?? 0}') ?? 0;
    final whenLabel = _relativeLabel(tx['timestamp'] as String?, tx['date'] as String?);

    final icon = switch (kind) {
      'income' => Icons.payments_outlined,
      'expense' => Icons.assignment_outlined,
      _ => Icons.shopping_bag_outlined,
    };
    final amountColor = switch (kind) {
      'income' => _kAccentBlue,
      'expense' => _kRed,
      _ => scheme.onSurface,
    };
    final prefix = kind == 'expense' ? '\u2212' : '';
    final iconBg = scheme.surfaceContainerHighest.withValues(alpha: 0.6);
    final iconColor = scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle == null || subtitle.isEmpty ? whenLabel : '$subtitle · $whenLabel',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$prefix${_currency.format(amount)}',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: amountColor),
          ),
        ],
      ),
    );
  }

  /// "2 hours ago" for today, "Yesterday" for the day before, otherwise a
  /// short absolute date — mirrors how the reference design labels rows.
  String _relativeLabel(String? isoTimestamp, String? isoDate) {
    final now = DateTime.now();
    final parsed = DateTime.tryParse(isoTimestamp ?? '') ?? DateTime.tryParse(isoDate ?? '');
    if (parsed == null) return '';

    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(parsed.year, parsed.month, parsed.day);
    final dayDiff = today.difference(day).inDays;

    if (dayDiff == 0) {
      if (isoTimestamp == null) return 'Today';
      final diff = now.difference(parsed);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    }
    if (dayDiff == 1) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(parsed);
  }

  Widget _quickAction(BuildContext context, IconData icon, String label, Color color, Widget screen) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: scheme.shadow.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}