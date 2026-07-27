import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../l10n/app_localizations.dart';
import '../../services/report_service.dart';
import '../../services/api_service.dart';
import '../../widgets/dialogs.dart';
import 'received_stock/received_stock_screen.dart';
import 'returned_stock/returned_stock_screen.dart';
import 'payments/payments_screen.dart';
import 'bills/retailer_bills_screen.dart';
import 'reports/retailer_reports_screen.dart';

// Same brand palette used on the admin dashboard so the retailer portal
// reads as part of the same app rather than a bolt-on redesign.
const _kTeal = Color(0xFF0D9488);
const _kAccentBlue = Color(0xFF3B82F6);
const _kAmber = Color(0xFFF59E0B);
const _kGreen = Color(0xFF10B981);

class RetailerDashboardScreen extends StatefulWidget {
  const RetailerDashboardScreen({super.key});

  @override
  State<RetailerDashboardScreen> createState() => _RetailerDashboardScreenState();
}

class _RetailerDashboardScreenState extends State<RetailerDashboardScreen> {
  String _period = 'weekly';
  Map<String, dynamic>? _data;
  bool _loading = true;

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '\u20b9', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _data = await ReportService.retailerDashboard(_period);
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

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            t.t('quickActions'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _quickAction(context, Icons.move_to_inbox_outlined, t.t('receivedStock'), _kAccentBlue,
                  const ReceivedStockScreen()),
              _quickAction(
                  context, Icons.undo_rounded, t.t('returnStock'), _kAmber, const ReturnedStockScreen()),
              _quickAction(
                  context, Icons.currency_rupee, t.t('cashPayment'), _kGreen, const PaymentsScreen()),
              _quickAction(
                  context, Icons.receipt_long_outlined, t.t('bills'), _kAccentBlue, const RetailerBillsScreen()),
            ],
          ),
          const SizedBox(height: 24),
          _earningsCard(context, t, scheme),
          const SizedBox(height: 24),
          _recentTransactionsSection(context, t, scheme),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // My Earnings card: weekly/monthly pill toggle + bar chart + current
  // balance, all inside one rounded surface.
  // ---------------------------------------------------------------------
  Widget _earningsCard(BuildContext context, AppLocalizations t, ColorScheme scheme) {
    final balance = double.tryParse('${_data?['current_balance'] ?? 0}') ?? 0;
    final isDue = balance > 0.005;

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
                  t.t('myEarnings'),
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
          // Label + amount and the status chip are stacked vertically
          // (rather than side-by-side in one Row) so a long translation
          // for "Balance due" / "All settled up" can wrap onto its own
          // line instead of squeezing the amount column down to nothing.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.t('currentBalance').toUpperCase(),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _currency.format(balance.abs()),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _kTeal),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: (isDue ? _kAmber : _kGreen).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(isDue ? Icons.schedule : Icons.check_circle_outline,
                        size: 15, color: isDue ? _kAmber : _kGreen),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isDue ? t.t('balanceDue') : t.t('allSettled'),
                        softWrap: true,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDue ? _kAmber : _kGreen,
                        ),
                      ),
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
              color: selected ? _kTeal : scheme.onSurfaceVariant,
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
    final chart = (_data?['earnings_chart'] as List?) ?? [];
    if (chart.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(t.t('noEarningsData'), style: TextStyle(color: scheme.onSurfaceVariant)),
        ),
      );
    }

    // Keep only the most recent points so the bars stay wide and legible.
    final trimmed = chart.length > 6 ? chart.sublist(chart.length - 6) : chart;

    double maxEarnings = 0;
    final values = <double>[];
    final labels = <String>[];
    for (final row in trimmed) {
      final map = Map<String, dynamic>.from(row);
      final earnings = double.tryParse('${map['earnings'] ?? 0}') ?? 0;
      values.add(earnings);
      if (earnings > maxEarnings) maxEarnings = earnings;
      labels.add(_periodLabel('${map['period'] ?? ''}'));
    }
    final maxY = maxEarnings <= 0 ? 10.0 : maxEarnings * 1.25;

    final bars = <BarChartGroupData>[];
    for (var i = 0; i < values.length; i++) {
      final isPeak = values[i] == maxEarnings && maxEarnings > 0;
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
                    ? [_kTeal, const Color(0xFF2DD4BF)]
                    : [_kTeal.withValues(alpha: 0.55), _kTeal.withValues(alpha: 0.85)],
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
            getDrawingHorizontalLine: (_) =>
                FlLine(color: scheme.outlineVariant.withValues(alpha: 0.3), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: maxY / 4,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  return Text(
                    _compactCurrency(value),
                    style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
                  );
                },
              ),
            ),
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

  /// Short axis label such as "1.5K" instead of the full rupee amount, so
  /// the left-hand scale stays readable at a glance.
  String _compactCurrency(double value) {
    if (value >= 100000) return '${(value / 100000).toStringAsFixed(value % 100000 == 0 ? 0 : 1)}L';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    return value.toStringAsFixed(0);
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

  // ---------------------------------------------------------------------
  // Recent Transactions: header + "View Reports" link, then a rounded list
  // card mirroring each stock/bill/payment event for this retailer.
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
            TextButton(
              onPressed: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const RetailerReportsScreen())),
              style: TextButton.styleFrom(foregroundColor: _kTeal),
              child: Text(t.t('viewReports'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 4),
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
                  _transactionTile(context, t, Map<String, dynamic>.from(transactions[i]), scheme),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _transactionTile(BuildContext context, AppLocalizations t, Map<String, dynamic> tx, ColorScheme scheme) {
    final kind = '${tx['kind'] ?? 'bill'}'; // bill | stock_in | stock_out | payment
    final refId = tx['ref_id'] ?? tx['id'] ?? '';
    final status = tx['status'] as String?; // due | settled | null
    final itemsCount = tx['items_count'];
    final amount = tx['amount'] == null ? null : double.tryParse('${tx['amount']}');
    final whenLabel = _relativeLabel(t, tx['date'] as String?);

    final title = switch (kind) {
      'stock_in' => '${t.t('stockReceivedTx')} #$refId',
      'stock_out' => '${t.t('stockReturnedTx')} #$refId',
      'payment' => '${t.t('cashPaymentTx')} #$refId',
      _ => '${t.t('invoiceLabel')} #$refId',
    };
    final subtitle = switch (kind) {
      'stock_in' || 'stock_out' => '${itemsCount ?? 0} ${t.t('itemsTx')}',
      'payment' => t.t('paidToCompanyTx'),
      _ => status == 'due' ? t.t('balanceDueTx') : t.t('settledLabel'),
    };

    final (icon, amountColor) = switch (kind) {
      'stock_in' => (Icons.move_to_inbox_outlined, scheme.onSurface),
      'stock_out' => (Icons.undo_rounded, scheme.onSurface),
      'payment' => (Icons.payments_outlined, _kGreen),
      _ => (Icons.receipt_long_outlined, _kTeal),
    };
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
                  subtitle.isEmpty ? whenLabel : '$subtitle \u00b7 $whenLabel',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (amount != null)
            Text(
              _currency.format(amount),
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: amountColor),
            ),
        ],
      ),
    );
  }

  /// Date-based label mirroring the admin dashboard's cases: "Today",
  /// "Yesterday", or a short absolute date (no time component is returned
  /// by this endpoint). Both relative words are localized; the absolute
  /// date follows the app's current locale automatically via intl.
  String _relativeLabel(AppLocalizations t, String? isoDate) {
    final parsed = DateTime.tryParse(isoDate ?? '');
    if (parsed == null) return '';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(parsed.year, parsed.month, parsed.day);
    final dayDiff = today.difference(day).inDays;

    if (dayDiff == 0) return t.t('todayLabel');
    if (dayDiff == 1) return t.t('yesterdayLabel');
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