import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/network_url.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/bill.dart';
import '../../../models/company.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/bill_service.dart';
import '../../../services/api_service.dart';
import '../../../widgets/bill_receipt_dialog.dart';
import '../../../widgets/date_group_header.dart';
import '../../../widgets/dialogs.dart';
import '../../../widgets/settle_bill_dialog.dart';

// Brand accent - stays constant across light/dark, everything else reads
// from Theme.of(context).colorScheme so the screen adapts automatically.
const _kAccentBlue = Color(0xFF3B82F6);
const _kAmber = Color(0xFFF59E0B);
const _kGreen = Color(0xFF10B981);

// Rotating icon/colour combo for each bill row's leading badge, purely
// decorative — mirrors the assorted store icons in the reference design.
const _kRowBadges = [
  (Icons.storefront_outlined, Color(0xFF3B82F6)),
  (Icons.eco_outlined, Color(0xFF10B981)),
  (Icons.description_outlined, Color(0xFFF59E0B)),
  (Icons.inventory_2_outlined, Color(0xFFDB2777)),
];

class BillHistoryScreen extends ConsumerStatefulWidget {
  const BillHistoryScreen({super.key});

  @override
  ConsumerState<BillHistoryScreen> createState() => _BillHistoryScreenState();
}

class _BillHistoryScreenState extends ConsumerState<BillHistoryScreen> {
  List<Bill> _items = [];
  bool _loading = true;
  Company? _company;

  @override
  void initState() {
    super.initState();
    _load();
    _loadCompany();
  }

  /// Best-effort load of company details for the receipt header. A missing
  /// company profile shouldn't block viewing bill history, so failures are
  /// silent — the receipt still renders fine without them.
  Future<void> _loadCompany() async {
    try {
      final res = await ApiService.get(NetworkUrl.company);
      if (mounted) setState(() => _company = Company.fromJson(res));
    } catch (_) {
      // Ignore — receipt just shows without company header details.
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await BillService.list();
      items.sort((a, b) => b.date.compareTo(a.date));
      _items = items;
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Groups bills by date (newest first, per [_load]'s sort), preserving
  /// that order via a LinkedHashMap so each date section prints in order.
  Map<String, List<Bill>> _groupByDate(List<Bill> bills) =>
      groupByDate<Bill>(bills, (b) => b.date, (d) => DateFormat('dd-MM-yyyy').format(d));

  Future<void> _preview(Bill b) async {
    final updated = await showBillReceiptDialog(context, bill: b, company: _company);
    if (updated != null && mounted) {
      setState(() {
        final idx = _items.indexWhere((x) => x.id == updated.id);
        if (idx != -1) _items[idx] = updated;
      });
    }
  }

  Future<void> _delete(Bill b) async {
    final t = context.l10n;
    final ok = await confirmDialog(context, title: t.t('deleteBill'), message: t.t('deleteBillConfirm'));
    if (!ok) return;
    try {
      await BillService.delete(b.id!);
      _load();
    } on ApiException catch (e) {
      showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _settle(Bill b) async {
    final t = context.l10n;
    final amount = await showSettleBillDialog(
      context,
      retailerName: b.retailerName ?? 'Retailer #${b.retailerId}',
      outstanding: b.grandTotal,
    );
    if (amount == null || amount <= 0 || b.id == null) return;
    try {
      final updated = await BillService.settle(b.id!, amount);
      if (mounted) {
        showSnack(context, t.t('billSettledSuccess'));
        setState(() {
          final idx = _items.indexWhere((x) => x.id == updated.id);
          if (idx != -1) _items[idx] = updated;
        });
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Widget _billCard(BuildContext context, ColorScheme scheme, AppLocalizations t, Bill b, int badgeIndex, bool isAdmin) {
    final badge = _kRowBadges[badgeIndex % _kRowBadges.length];
    final hasOutstanding = b.grandTotal > 0.005;
    final isSettled = !hasOutstanding && b.settledAmount > 0.005;
    final displayAmount = hasOutstanding ? b.grandTotal : (isSettled ? b.settledAmount : b.grandTotal);
    final amountColor = hasOutstanding ? _kAmber : (isSettled ? _kGreen : scheme.onSurface);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: scheme.shadow.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _preview(b),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: badge.$2.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                  child: Icon(badge.$1, size: 18, color: badge.$2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    b.retailerName ?? 'Retailer #${b.retailerId}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: scheme.onSurface),
                  ),
                ),
                if (isAdmin)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    onPressed: () => _delete(b),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.t('totalAmount'), style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      Text(
                        'Rs. ${displayAmount.toStringAsFixed(2)}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: amountColor),
                      ),
                    ],
                  ),
                ),
                if (hasOutstanding)
                  FilledButton(
                    onPressed: () => _settle(b),
                    style: FilledButton.styleFrom(
                      backgroundColor: kDateGroupNavy,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(t.t('settleNow'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  )
                else if (isSettled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: _kGreen.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, size: 14, color: _kGreen),
                        const SizedBox(width: 5),
                        Text(t.t('settledLabel').toUpperCase(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _kGreen)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final isAdmin = ref.watch(authProvider).user!.isAdmin;
    final grouped = _groupByDate(_items);

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kAccentBlue))
          : RefreshIndicator(
              color: _kAccentBlue,
              onRefresh: _load,
              child: _items.isEmpty
                  ? Center(
                      child: Text(
                        t.t('noBillsYet'),
                        style: TextStyle(color: scheme.outline),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        for (final entry in grouped.entries) ...[
                          dateGroupHeader(scheme, entry.key),
                          for (int i = 0; i < entry.value.length; i++)
                            _billCard(context, scheme, t, entry.value[i], _items.indexOf(entry.value[i]), isAdmin),
                        ],
                      ],
                    ),
            ),
    );
  }
}