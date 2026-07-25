import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../config/network_url.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/retailer.dart';
import '../../../services/crud_service.dart';
import '../../../services/report_service.dart';
import '../../../services/api_service.dart';
import '../../../utils/num_format.dart';
import '../../../widgets/dialogs.dart';

const _kAccentBlue = Color(0xFF3B82F6);

/// Stock Reports (mirrors Sales Reports, in quantity terms instead of Rs.)
class StockReportScreen extends StatefulWidget {
  const StockReportScreen({super.key});

  @override
  State<StockReportScreen> createState() => _StockReportScreenState();
}

class _StockReportScreenState extends State<StockReportScreen> {
  final _retailerService = CrudService<Retailer>(NetworkUrl.retailers, Retailer.fromJson);

  String _type = 'total';
  DateTimeRange? _range; // null => backend defaults to last 30 days
  int? _retailerId;
  List<Retailer> _retailers = [];
  Map<String, dynamic>? _result;
  bool _loading = false;
  bool _loadingRetailers = true;

  bool get _needsRetailer => _type == 'retailer' || _type == 'holding_retailer';
  bool get _hasDateRange => _type == 'total' || _type == 'retailer';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      _retailers = await _retailerService.list();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loadingRetailers = false);
    }
    _run();
  }

  Future<void> _run() async {
    if (_needsRetailer && _retailerId == null) {
      setState(() => _result = null);
      return;
    }
    setState(() => _loading = true);
    try {
      final from = _range != null ? DateFormat('yyyy-MM-dd').format(_range!.start) : null;
      final to = _range != null ? DateFormat('yyyy-MM-dd').format(_range!.end) : null;
      final result = await ReportService.stock(_type, from: from, to: to, retailerId: _retailerId);
      setState(() => _result = result);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _rangeLabel(AppLocalizations t) {
    if (_range == null) return t.t('last30Days');
    return '${DateFormat('dd-MM-yyyy').format(_range!.start)} - ${DateFormat('dd-MM-yyyy').format(_range!.end)}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = context.l10n;

    final stockTypes = [
      {'value': 'total', 'label': t.t('totalStockSales')},
      {'value': 'holding', 'label': t.t('holdingTotalStock')},
      {'value': 'retailer', 'label': t.t('retailerTotalStockSales')},
      {'value': 'holding_retailer', 'label': t.t('holdingRetailerTotalStock')},
    ];

    return Scaffold(
      appBar: AppBar(title: Text(t.t('stockReports'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _type,
            isExpanded: true,
            decoration: InputDecoration(labelText: t.t('reportType'), border: const OutlineInputBorder()),
            items: stockTypes
                .map((ty) => DropdownMenuItem(
                      value: ty['value'],
                      child: Text(ty['label']!, overflow: TextOverflow.ellipsis),
                    ))
                .toList(),
            onChanged: (v) {
              setState(() => _type = v!);
              _run();
            },
          ),
          if (_needsRetailer) ...[
            const SizedBox(height: 12),
            _loadingRetailers
                ? const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: _kAccentBlue)))
                : DropdownButtonFormField<int>(
                    initialValue: _retailerId,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: t.t('retailer'), border: const OutlineInputBorder()),
                    hint: Text(t.t('selectRetailer')),
                    items: _retailers
                        .map((r) => DropdownMenuItem(
                              value: r.id,
                              child: Text(r.name, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _retailerId = v);
                      _run();
                    },
                  ),
          ],
          if (_hasDateRange) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(_rangeLabel(t)),
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDateRange: _range,
                      );
                      if (picked != null) {
                        setState(() => _range = picked);
                        _run();
                      }
                    },
                  ),
                ),
                if (_range != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: t.t('resetTo30DaysTooltip'),
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() => _range = null);
                      _run();
                    },
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: _kAccentBlue))
          else if (_needsRetailer && _retailerId == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(t.t('selectRetailerToView'), style: TextStyle(color: scheme.outline)),
              ),
            )
          else
            _buildStockResult(scheme, t),
        ],
      ),
    );
  }

  Widget _buildStockResult(ColorScheme scheme, AppLocalizations t) {
    if (_result == null) return const SizedBox.shrink();
    switch (_type) {
      case 'total':
        return _totalStockView(scheme, t);
      case 'holding':
        return _holdingStockView(scheme, t);
      case 'retailer':
        return _retailerStockView(scheme, t);
      case 'holding_retailer':
        return _holdingRetailerStockView(scheme, t);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _summaryChip(ColorScheme scheme, String label, double value, {Color? color}) {
    final c = color ?? _kAccentBlue;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Qty ${value.qty}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c)),
          ],
        ),
      ),
    );
  }

  /// Total Stock Sales: Date/Retailer/Qty table for the selected window, with
  /// a last-month vs this-month comparison up top and a grand total at the bottom.
  Widget _totalStockView(ColorScheme scheme, AppLocalizations t) {
    final rows = (_result!['rows'] as List).map((r) => Map<String, dynamic>.from(r)).toList();
    final lastMonthTotal = (num.tryParse('${_result!['last_month_total'] ?? 0}') ?? 0).toDouble();
    final thisMonthTotal = (num.tryParse('${_result!['this_month_total'] ?? 0}') ?? 0).toDouble();
    final periodTotal = (num.tryParse('${_result!['period_total'] ?? 0}') ?? 0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _summaryChip(scheme, t.t('lastMonthTotal'), lastMonthTotal, color: const Color(0xFFF59E0B)),
            _summaryChip(scheme, t.t('thisMonthTotal'), thisMonthTotal, color: const Color(0xFF10B981)),
          ],
        ),
        const SizedBox(height: 16),
        if (rows.isEmpty)
          _emptyCard(scheme, t.t('noStockSoldPeriod'))
        else
          _card(
            scheme,
            child: Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(scheme.surfaceContainerHighest.withValues(alpha: 0.5)),
                    columns: [
                      DataColumn(label: Text(t.t('date'))),
                      DataColumn(label: Text(t.t('retailer'))),
                      DataColumn(label: Text(t.t('product'))),
                      DataColumn(label: Text(t.t('qty')), numeric: true),
                    ],
                    rows: rows.map((r) {
                      final date = DateTime.tryParse(r['date'] ?? '') ?? DateTime.now();
                      final qty = (num.tryParse('${r['qty'] ?? 0}') ?? 0).toDouble();
                      return DataRow(cells: [
                        DataCell(Text(DateFormat('dd-MM-yyyy').format(date))),
                        DataCell(Text(r['retailer_name'] ?? '-')),
                        DataCell(Text(r['product_name'] ?? '-')),
                        DataCell(Text(qty.qty)),
                      ]);
                    }).toList(),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t.t('totalOfPeriod'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Qty ${periodTotal.qty}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _kAccentBlue)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Holding Total Stock: product-wise stock currently held across all retailers.
  Widget _holdingStockView(ColorScheme scheme, AppLocalizations t) {
    final rows = (_result!['rows'] as List).map((r) => Map<String, dynamic>.from(r)).toList();
    final total = (num.tryParse('${_result!['total_holding_qty'] ?? 0}') ?? 0).toDouble();

    if (rows.isEmpty) return _emptyCard(scheme, t.t('noProductHeldByRetailer'));

    return _card(
      scheme,
      child: Column(
        children: [
          ...rows.map((r) {
            final qty = (num.tryParse('${r['holding_qty'] ?? 0}') ?? 0).toDouble();
            return ListTile(
              leading: const CircleAvatar(backgroundColor: Color(0x1A10B981), child: Icon(Icons.icecream_outlined, color: Color(0xFF10B981))),
              title: Text(r['product_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: Text('Qty ${qty.qty}', style: const TextStyle(fontWeight: FontWeight.w700)),
            );
          }),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(t.t('totalHoldingQty'), style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Qty ${total.qty}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _kAccentBlue)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Retailer Total Stock Sales: a single retailer's own Date/Qty sold rows.
  Widget _retailerStockView(ColorScheme scheme, AppLocalizations t) {
    final rows = (_result!['rows'] as List).map((r) => Map<String, dynamic>.from(r)).toList();
    final total = (num.tryParse('${_result!['total_sold_qty'] ?? 0}') ?? 0).toDouble();
    final name = _result!['retailer_name'] ?? '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: scheme.onSurface)),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          _emptyCard(scheme, t.t('noStockSoldForRetailerPeriod'))
        else
          _card(
            scheme,
            child: Column(
              children: [
                ...rows.map((r) {
                  final date = DateTime.tryParse(r['date'] ?? '') ?? DateTime.now();
                  final qty = (num.tryParse('${r['qty'] ?? 0}') ?? 0).toDouble();
                  return ListTile(
                    leading: const Icon(Icons.calendar_today_outlined, size: 18),
                    title: Text(r['product_name'] ?? '-'),
                    subtitle: Text(DateFormat('dd-MM-yyyy').format(date)),
                    trailing: Text('Qty ${qty.qty}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  );
                }),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t.t('totalStockSold'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Qty ${total.qty}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _kAccentBlue)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Holding Retailer Total Stock: a single retailer's current holding,
  /// broken down by product (qty only, no Rs. value).
  Widget _holdingRetailerStockView(ColorScheme scheme, AppLocalizations t) {
    final rows = (_result!['rows'] as List).map((r) => Map<String, dynamic>.from(r)).toList();
    final total = (num.tryParse('${_result!['total_holding_qty'] ?? 0}') ?? 0).toDouble();
    final name = _result!['retailer_name'] ?? '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: scheme.onSurface)),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          _emptyCard(scheme, t.t('noUnbilledHoldingStock'))
        else
          _card(
            scheme,
            child: Column(
              children: [
                ...rows.map((r) {
                  final qty = (num.tryParse('${r['holding_qty'] ?? 0}') ?? 0).toDouble();
                  return ListTile(
                    title: Text(r['product_name'] ?? '-'),
                    trailing: Text('Qty ${qty.qty}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  );
                }),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(t.t('totalHoldingQty'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Qty ${total.qty}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _kAccentBlue)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _card(ColorScheme scheme, {required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: scheme.shadow.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _emptyCard(ColorScheme scheme, String message) {
    return _card(
      scheme,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(child: Text(message, style: TextStyle(color: scheme.outline))),
      ),
    );
  }
}