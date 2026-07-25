import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../config/api_config.dart';
import '../../../config/network_url.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/bill.dart';
import '../../../models/cash_payment.dart';
import '../../../models/company.dart';
import '../../../models/retailer.dart';
import '../../../models/stock_entry.dart';
import '../../../services/bill_service.dart';
import '../../../services/cash_payment_service.dart';
import '../../../services/crud_service.dart';
import '../../../services/api_service.dart';
import '../../../services/stock_service.dart';
import '../../../utils/num_format.dart';
import '../../../widgets/bill_preview_card.dart';
import '../../../widgets/bill_receipt_dialog.dart';
import '../../../widgets/dialogs.dart';

// Brand accent - stays constant across light/dark, everything else reads
// from Theme.of(context).colorScheme so the screen adapts automatically.
const _kAccentBlue = Color(0xFF3B82F6);

class BillGenerateScreen extends StatefulWidget {
  const BillGenerateScreen({super.key});

  @override
  State<BillGenerateScreen> createState() => _BillGenerateScreenState();
}

class _BillGenerateScreenState extends State<BillGenerateScreen> {
  final _retailerService = CrudService<Retailer>(NetworkUrl.retailers, Retailer.fromJson);
  final _giveStockService = StockService(NetworkUrl.giveStock);
  final _returnStockService = StockService(NetworkUrl.returnStock);
  List<Retailer> _retailers = [];
  Company? _company;
  int? _retailerId;
  DateTime _date = DateTime.now();
  Bill? _preview;
  bool _loadingRetailers = true;
  bool _previewing = false;
  bool _generating = false;

  // Date-wise pending records for the selected retailer, shown in their own
  // containers so the admin can verify exactly what will go into the bill.
  List<StockEntry> _givenStock = [];
  List<StockEntry> _returnedStock = [];
  List<CashPayment> _cashPayments = [];
  bool _loadingTxns = false;

  @override
  void initState() {
    super.initState();
    _loadRetailers();
  }

  Future<void> _loadRetailers() async {
    try {
      _retailers = await _retailerService.list();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loadingRetailers = false);
    }
    _loadCompany();
  }

  /// Best-effort load of company details for the receipt header. A missing
  /// company profile shouldn't block bill generation, so failures are silent.
  Future<void> _loadCompany() async {
    try {
      final res = await ApiService.get(NetworkUrl.company);
      if (mounted) setState(() => _company = Company.fromJson(res));
    } catch (_) {
      // Receipt still prints fine without company header details.
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) {
      setState(() => _date = picked);
      _loadTransactionRecords();
    }
  }

  Retailer? get _selectedRetailer {
    if (_retailerId == null) return null;
    for (final r in _retailers) {
      if (r.id == _retailerId) return r;
    }
    return null;
  }

  List<Color> _avatarPalette(BuildContext context, int seed) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const hues = [
      Color(0xFF6366F1),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFDB2777),
    ];
    final hue = hues[seed % hues.length];
    return [hue.withValues(alpha: isDark ? 0.28 : 0.15), hue];
  }

  Future<void> _pickRetailer() async {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    String search = '';

    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final filtered = search.isEmpty
              ? _retailers
              : _retailers.where((r) => r.name.toLowerCase().contains(search.toLowerCase())).toList();
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.7,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: t.t('searchRetailer'),
                          prefixIcon: Icon(Icons.search, color: scheme.outline),
                          filled: true,
                          fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          isDense: true,
                        ),
                        onChanged: (v) => setSheetState(() => search = v),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final r = filtered[i];
                          final palette = _avatarPalette(context, i);
                          return ListTile(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            leading: CircleAvatar(
                              backgroundColor: palette[0],
                              backgroundImage: r.profileImage != null
                                  ? NetworkImage('${ApiConfig.imageBaseUrl}/${r.profileImage!}')
                                  : null,
                              child: r.profileImage == null
                                  ? Text(
                                      r.name.isNotEmpty ? r.name[0].toUpperCase() : '?',
                                      style: TextStyle(color: palette[1], fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            title: Text(r.name, style: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface)),
                            subtitle: Text(r.phoneNumber, style: TextStyle(color: scheme.onSurfaceVariant)),
                            onTap: () => Navigator.pop(ctx, r.id),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (picked != null) {
      setState(() {
        _retailerId = picked;
        _preview = null;
      });
      _loadTransactionRecords();
    }
  }

  /// Fetches date-wise pending (not-yet-billed) give-stock, return-stock, and
  /// cash-payment records for the selected retailer, up to the selected
  /// billing date — the same records that make up the bill preview/total.
  Future<void> _loadTransactionRecords() async {
    if (_retailerId == null) return;
    final dateStr = DateFormat('yyyy-MM-dd').format(_date);
    setState(() => _loadingTxns = true);
    try {
      final results = await Future.wait([
        _giveStockService.list(retailerId: _retailerId, dateTo: dateStr, isBilled: false, perPage: 100),
        _returnStockService.list(retailerId: _retailerId, dateTo: dateStr, isBilled: false, perPage: 100),
        CashPaymentService.list(retailerId: _retailerId, dateTo: dateStr, isBilled: false, perPage: 100),
      ]);
      if (!mounted) return;
      setState(() {
        _givenStock = results[0] as List<StockEntry>;
        _returnedStock = results[1] as List<StockEntry>;
        _cashPayments = results[2] as List<CashPayment>;
      });
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loadingTxns = false);
    }
  }

  Future<void> _doPreview() async {
    final t = context.l10n;
    if (_retailerId == null) {
      showSnack(context, t.t('selectRetailerFirst'), isError: true);
      return;
    }
    if (_givenStock.isEmpty) {
      showSnack(context, t.t('noGiveStockForBillError'), isError: true);
      return;
    }
    setState(() => _previewing = true);
    try {
      final bill = await BillService.preview(_retailerId!, DateFormat('yyyy-MM-dd').format(_date));
      setState(() => _preview = bill);
    } on ApiException catch (e) {
      showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _doGenerate() async {
    final t = context.l10n;
    if (_retailerId == null) return;
    if (_givenStock.isEmpty) {
      showSnack(context, t.t('noGiveStockForBillError'), isError: true);
      return;
    }
    final ok = await confirmDialog(context, title: t.t('generateBillTitle'), message: t.t('generateBillConfirm'));
    if (!ok) return;

    setState(() => _generating = true);
    try {
      final bill = await BillService.generate(_retailerId!, DateFormat('yyyy-MM-dd').format(_date));
      if (mounted) {
        showSnack(context, t.t('billGeneratedSuccess'));
        setState(() => _preview = bill);
        _loadTransactionRecords();
      }

      // Receipt popup: admin can print the bill and, via the "Settle in
      // Full" checkbox, settle the outstanding amount at the same time.
      // Leaving it unchecked (or hitting Cancel) leaves the bill generated
      // but not settled, i.e. "not now".
      if (mounted) {
        final result = await showBillReceiptDialog(context, bill: bill, company: _company);
        if (result != null && mounted) {
          setState(() => _preview = result);
          if (result.grandTotal <= 0.005 && bill.grandTotal > 0.005) {
            showSnack(context, t.t('billSettledSuccess'));
          }
        }
      }
    } on ApiException catch (e) {
      showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Widget _sectionContainer(ColorScheme scheme, {required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: scheme.shadow.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionHeader(ColorScheme scheme, IconData icon, Color accent, String title, String totalLabel) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 16, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: scheme.onSurface)),
        ),
        Text(totalLabel, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: accent)),
      ],
    );
  }

  /// Groups [entries] by date, then by product, summing quantities so a
  /// single date row can show every product's quantity for that day.
  Map<String, Map<String, double>> _pivotByDate(List<StockEntry> entries) {
    final map = <String, Map<String, double>>{};
    for (final e in entries) {
      final dateKey = DateFormat('dd-MM-yyyy').format(e.date);
      final row = map.putIfAbsent(dateKey, () => {});
      for (final item in e.items) {
        final name = item.productName ?? 'Product #${item.productId}';
        row[name] = (row[name] ?? 0) + item.quantity;
      }
    }
    return map;
  }

  /// Date x Product pivot table — rows are dates, columns are products,
  /// each cell is the quantity for that product on that date ('-' if none).
  Widget _pivotTable(ColorScheme scheme, Color accent, List<StockEntry> entries, Map<String, double> productTotals) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final products = productTotals.keys.toList();
    final pivot = _pivotByDate(entries);
    final dates = pivot.keys.toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(scheme.surfaceContainerHighest.withValues(alpha: 0.5)),
        headingTextStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
        dataTextStyle: TextStyle(fontSize: 12, color: scheme.onSurface),
        columnSpacing: 20,
        horizontalMargin: 12,
        headingRowHeight: 40,
        dataRowMinHeight: 34,
        dataRowMaxHeight: 38,
        columns: [
          const DataColumn(label: Text('Date/Products')),
          ...products.map((p) => DataColumn(label: Text(p))),
        ],
        rows: dates.map((d) {
          final row = pivot[d]!;
          return DataRow(cells: [
            DataCell(Text(d, style: TextStyle(color: scheme.onSurfaceVariant))),
            ...products.map((p) => DataCell(Text(row[p] != null ? row[p]!.qty : '-'))),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _cashPaymentRow(ColorScheme scheme, CashPayment p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined, size: 12, color: scheme.outline),
          const SizedBox(width: 6),
          Text(DateFormat('dd-MM-yyyy').format(p.date), style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
          const Spacer(),
          Text('Rs. ${p.amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: scheme.onSurface)),
        ],
      ),
    );
  }

  /// Aggregates quantities per product across every entry in [entries],
  /// e.g. multiple give-stock rows on different dates for the same product
  /// are summed into a single product-wise total.
  Map<String, double> _productTotals(List<StockEntry> entries) {
    final totals = <String, double>{};
    for (final e in entries) {
      for (final item in e.items) {
        final key = item.productName ?? 'Product #${item.productId}';
        totals[key] = (totals[key] ?? 0) + item.quantity;
      }
    }
    return totals;
  }

  Widget _productTotalsWrap(ColorScheme scheme, Color accent, Map<String, double> totals) {
    if (totals.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: totals.entries
          .map(
            (e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${e.key} · ${e.value.qty}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accent),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _emptyRow(ColorScheme scheme, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(label, style: TextStyle(fontSize: 12.5, color: scheme.outline)),
    );
  }

  /// The three "date wise" containers: given stock, returned stock, and cash
  /// payments pending for the selected retailer, up to the billing date.
  Widget _buildRecordsSection(BuildContext context, AppLocalizations t, ColorScheme scheme) {
    if (_loadingTxns) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: _kAccentBlue)),
      );
    }

    final givenTotalQty = _givenStock.fold<double>(0, (sum, e) => sum + e.items.fold<double>(0, (s, i) => s + i.quantity));
    final returnedTotalQty = _returnedStock.fold<double>(0, (sum, e) => sum + e.items.fold<double>(0, (s, i) => s + i.quantity));
    final cashTotal = _cashPayments.fold<double>(0, (sum, p) => sum + p.amount);
    final givenProductTotals = _productTotals(_givenStock);
    final returnedProductTotals = _productTotals(_returnedStock);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.t('pendingRecords'), style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),

        // 1. Give stock (products dispatched to retailer)
        _sectionContainer(
          scheme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(scheme, Icons.inventory_2_outlined, const Color(0xFF10B981), t.t('giveStockRecords'), 'Qty ${givenTotalQty.qty}'),
              if (givenProductTotals.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(t.t('productWiseTotal'), style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                _productTotalsWrap(scheme, const Color(0xFF10B981), givenProductTotals),
              ],
              const Divider(height: 16),
              if (_givenStock.isEmpty)
                _emptyRow(scheme, t.t('noRecordsFound'))
              else ...[
                _pivotTable(scheme, const Color(0xFF10B981), _givenStock, givenProductTotals),
                const SizedBox(height: 6),
                Text(t.t('perDayQtyNote'), style: TextStyle(fontSize: 10.5, color: scheme.outline, fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),

        // 2. Return stock (products returned by retailer)
        _sectionContainer(
          scheme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(scheme, Icons.keyboard_return_outlined, const Color(0xFFF59E0B), t.t('returnStockRecords'), 'Qty ${returnedTotalQty.qty}'),
              if (returnedProductTotals.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(t.t('productWiseTotal'), style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                _productTotalsWrap(scheme, const Color(0xFFF59E0B), returnedProductTotals),
              ],
              const Divider(height: 16),
              if (_returnedStock.isEmpty)
                _emptyRow(scheme, t.t('noRecordsFound'))
              else ...[
                _pivotTable(scheme, const Color(0xFFF59E0B), _returnedStock, returnedProductTotals),
                const SizedBox(height: 6),
                Text(t.t('perDayQtyNote'), style: TextStyle(fontSize: 10.5, color: scheme.outline, fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),

        // 3. Cash payments made by retailer
        _sectionContainer(
          scheme,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionHeader(scheme, Icons.payments_outlined, const Color(0xFF6366F1), t.t('cashPaymentRecords'), 'Rs. ${cashTotal.toStringAsFixed(2)}'),
              const Divider(height: 16),
              if (_cashPayments.isEmpty)
                _emptyRow(scheme, t.t('noRecordsFound'))
              else
                ..._cashPayments.map((p) => _cashPaymentRow(scheme, p)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final retailer = _selectedRetailer;
    final retailerPalette = retailer != null ? _avatarPalette(context, _retailers.indexOf(retailer)) : null;

    return Scaffold(
      body: _loadingRetailers
          ? const Center(child: CircularProgressIndicator(color: _kAccentBlue))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(t.t('retailer'), style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickRetailer,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: retailerPalette?[0] ?? scheme.surfaceContainerHighest,
                          backgroundImage: retailer?.profileImage != null
                              ? NetworkImage('${ApiConfig.imageBaseUrl}/${retailer!.profileImage!}')
                              : null,
                          child: retailer == null
                              ? Icon(Icons.storefront_outlined, size: 18, color: scheme.onSurfaceVariant)
                              : (retailer.profileImage == null
                                  ? Text(
                                      retailer.name.isNotEmpty ? retailer.name[0].toUpperCase() : '?',
                                      style: TextStyle(color: retailerPalette?[1], fontWeight: FontWeight.bold),
                                    )
                                  : null),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            retailer?.name ?? t.t('noRetailerSelected'),
                            style: TextStyle(
                              color: retailer == null ? scheme.outline : scheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right, color: scheme.outline),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(t.t('billingDate'), style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(t.t('billingDateHint'), style: TextStyle(fontSize: 11, color: scheme.outline)),
                const SizedBox(height: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 18, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 12),
                        Text(DateFormat('dd-MM-yyyy').format(_date), style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (_retailerId != null && !_loadingTxns && _givenStock.isEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            t.t('noGiveStockForBillError'),
                            style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: _kAccentBlue),
                          foregroundColor: _kAccentBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: (_previewing || (_retailerId != null && _givenStock.isEmpty)) ? null : _doPreview,
                        icon: const Icon(Icons.visibility_outlined),
                        label: Text(_previewing ? t.t('loadingLabel') : t.t('preview')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _kAccentBlue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: (_generating || (_retailerId != null && _givenStock.isEmpty)) ? null : _doGenerate,
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(_generating ? t.t('generatingLabel') : t.t('generate')),
                      ),
                    ),
                  ],
                ),
                if (_retailerId != null) ...[
                  const SizedBox(height: 24),
                  _buildRecordsSection(context, t, scheme),
                ],
                if (_preview != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: BillPreviewCard(bill: _preview!),
                  ),
                ],
              ],
            ),
    );
  }
}