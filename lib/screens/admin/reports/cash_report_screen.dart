import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/report_service.dart';
import '../../../services/api_service.dart';
import '../../../widgets/dialogs.dart';

const _kCreditGreen = Color(0xFF10B981);
const _kDebitRed = Color(0xFFEF4444);
const _kAccentBlue = Color(0xFF3B82F6);

/// Cash Report as a transaction ledger: every credit (cash payments /
/// bill settlements) and debit (raw material expenses, retailer loans)
/// in the selected range, with a running balance after each entry.
class CashReportScreen extends StatefulWidget {
  const CashReportScreen({super.key});

  @override
  State<CashReportScreen> createState() => _CashReportScreenState();
}

class _CashReportScreenState extends State<CashReportScreen> {
  String _filter = 'today';
  DateTimeRange? _range;
  Map<String, dynamic>? _data;
  bool _loading = true;

  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 2);

  static const _filterKeys = {
    'today': 'filterToday',
    'yesterday': 'filterYesterday',
    'this_week': 'filterThisWeek',
    'this_month': 'filterThisMonth',
    'custom': 'filterCustom',
  };

  static const _categoryKeys = {
    'cash_payment': 'catCashPayment',
    'bill_settlement': 'catBillSettlement',
    'raw_material_expense': 'catRawMaterialExpense',
    'retailer_loan': 'catRetailerLoan',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final from = _range != null ? DateFormat('yyyy-MM-dd').format(_range!.start) : null;
      final to = _range != null ? DateFormat('yyyy-MM-dd').format(_range!.end) : null;
      _data = await ReportService.cashReport(_filter, from: from, to: to);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _entryTitle(AppLocalizations t, Map<String, dynamic> e) {
    final label = t.t(_categoryKeys[e['category']] ?? '');
    final name = e['retailer_name'] as String?;
    if (name != null && name.isNotEmpty) return '$label - $name';
    final remarks = e['remarks'] as String?;
    if (remarks != null && remarks.isNotEmpty) return '$label - $remarks';
    return label;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(t.t('cashReports'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final f in _filterKeys.keys)
                        ChoiceChip(
                          label: Text(t.t(_filterKeys[f]!)),
                          selected: _filter == f,
                          onSelected: (_) async {
                            if (f == 'custom') {
                              final picked = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) setState(() => _range = picked);
                            }
                            setState(() => _filter = f);
                            _load();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_data != null) ...[
                    _summaryCard(scheme, t),
                    const SizedBox(height: 20),
                    Text(t.t('transactions'), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: scheme.onSurface)),
                    const SizedBox(height: 10),
                    _transactionsList(scheme, t),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _summaryCard(ColorScheme scheme, AppLocalizations t) {
    final opening = (num.tryParse('${_data!['opening_balance'] ?? 0}') ?? 0).toDouble();
    final totalCredit = (num.tryParse('${_data!['total_credit'] ?? 0}') ?? 0).toDouble();
    final totalDebit = (num.tryParse('${_data!['total_debit'] ?? 0}') ?? 0).toDouble();
    final closing = (num.tryParse('${_data!['closing_balance'] ?? 0}') ?? 0).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(t.t('closingBalance'), style: TextStyle(color: scheme.onPrimaryContainer.withValues(alpha: 0.8))),
          const SizedBox(height: 4),
          Text(_currency.format(closing), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _miniStat(t.t('openingBalanceRow'), opening, scheme.onPrimaryContainer)),
              Expanded(child: _miniStat(t.t('totalCredit'), totalCredit, _kCreditGreen)),
              Expanded(child: _miniStat(t.t('totalDebit'), totalDebit, _kDebitRed)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.85)), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(_currency.format(value), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
      ],
    );
  }

  Widget _transactionsList(ColorScheme scheme, AppLocalizations t) {
    final transactions = (_data!['transactions'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();

    if (transactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
        child: Center(child: Text(t.t('noTransactionsInPeriod'), style: TextStyle(color: scheme.outline))),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: scheme.shadow.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < transactions.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _transactionRow(scheme, t, transactions[i]),
          ],
        ],
      ),
    );
  }

  Widget _transactionRow(ColorScheme scheme, AppLocalizations t, Map<String, dynamic> e) {
    final isCredit = e['type'] == 'credit';
    final amount = (num.tryParse('${e['amount'] ?? 0}') ?? 0).toDouble();
    final runningBalance = (num.tryParse('${e['running_balance'] ?? 0}') ?? 0).toDouble();
    final date = DateTime.tryParse(e['date'] ?? '') ?? DateTime.now();
    final color = isCredit ? _kCreditGreen : _kDebitRed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
            child: Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_entryTitle(t, e), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: scheme.onSurface)),
                const SizedBox(height: 2),
                Text(DateFormat('dd-MM-yyyy').format(date), style: TextStyle(fontSize: 11.5, color: scheme.outline)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '-'} Rs. ${amount.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                '${t.t('runningBalance')}: ${_currency.format(runningBalance)}',
                style: TextStyle(fontSize: 10.5, color: scheme.outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}