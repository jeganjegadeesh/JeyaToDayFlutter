import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/api_config.dart';
import '../../../config/network_url.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/cash_payment.dart';
import '../../../models/retailer.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/cash_payment_service.dart';
import '../../../services/crud_service.dart';
import '../../../services/api_service.dart';
import '../../../widgets/date_group_header.dart';
import '../../../widgets/dialogs.dart';

// Brand accent - stays constant across light/dark, everything else reads
// from Theme.of(context).colorScheme so the screen adapts automatically.
const _kAccentBlue = Color(0xFF3B82F6);
const _kBilledAccent = Color(0xFF10B981);

class CashPaymentScreen extends ConsumerStatefulWidget {
  const CashPaymentScreen({super.key});

  @override
  ConsumerState<CashPaymentScreen> createState() => _CashPaymentScreenState();
}

class _CashPaymentScreenState extends ConsumerState<CashPaymentScreen> {
  final _retailerService = CrudService<Retailer>(NetworkUrl.retailers, Retailer.fromJson);
  List<CashPayment> _items = [];
  List<Retailer> _retailers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([CashPaymentService.list(), _retailerService.list()]);
      final items = results[0] as List<CashPayment>;
      items.sort((a, b) => b.date.compareTo(a.date));
      _items = items;
      _retailers = results[1] as List<Retailer>;
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  Retailer? _retailerById(int? id) {
    if (id == null) return null;
    for (final r in _retailers) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<int?> _pickRetailer(BuildContext context) async {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    String search = '';

    return showModalBottomSheet<int>(
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
  }

  void _openForm() {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    int? retailerId;
    DateTime date = DateTime.now();
    final amountCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final retailer = _retailerById(retailerId);
          final palette = retailer != null ? _avatarPalette(ctx, _retailers.indexOf(retailer)) : null;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              t.t('newPayment'),
              style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.bold),
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.t('retailer'),
                      style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        final picked = await _pickRetailer(ctx);
                        if (picked != null) setDialogState(() => retailerId = picked);
                      },
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
                              backgroundColor: palette?[0] ?? scheme.surfaceContainerHighest,
                              backgroundImage: retailer?.profileImage != null
                                  ? NetworkImage('${ApiConfig.imageBaseUrl}/${retailer!.profileImage!}')
                                  : null,
                              child: retailer == null
                                  ? Icon(Icons.storefront_outlined, size: 18, color: scheme.onSurfaceVariant)
                                  : (retailer.profileImage == null
                                      ? Text(
                                          retailer.name.isNotEmpty ? retailer.name[0].toUpperCase() : '?',
                                          style: TextStyle(color: palette?[1], fontWeight: FontWeight.bold),
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
                    const SizedBox(height: 14),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) setDialogState(() => date = picked);
                      },
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
                            Text(
                              DateFormat('dd-MM-yyyy').format(date),
                              style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: amountCtrl,
                      decoration: InputDecoration(
                        labelText: t.t('amount'),
                        prefixIcon: Icon(Icons.currency_rupee, color: scheme.onSurfaceVariant),
                        filled: true,
                        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => (v == null || double.tryParse(v) == null) ? t.t('validAmount') : null,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t.t('cancel'), style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _kAccentBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  if (!formKey.currentState!.validate() || retailerId == null) {
                    if (retailerId == null) showSnack(ctx, t.t('selectRetailerError'), isError: true);
                    return;
                  }
                  try {
                    await CashPaymentService.create(
                      retailerId!,
                      DateFormat('yyyy-MM-dd').format(date),
                      double.parse(amountCtrl.text),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    _load();
                  } on ApiException catch (e) {
                    showSnack(ctx, e.message, isError: true);
                  }
                },
                child: Text(t.t('save')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _delete(CashPayment p) async {
    final t = context.l10n;
    final ok = await confirmDialog(context, title: t.t('deletePayment'), message: t.t('deletePaymentConfirm'));
    if (!ok) return;
    try {
      await CashPaymentService.delete(p.id);
      _load();
    } on ApiException catch (e) {
      showSnack(context, e.message, isError: true);
    }
  }

  Widget _paymentCard(BuildContext context, AppLocalizations t, ColorScheme scheme, bool isAdmin, CashPayment p, int seed) {
    final palette = _avatarPalette(context, seed);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: palette[0],
            backgroundImage: p.retailerImage != null
                ? NetworkImage('${ApiConfig.imageBaseUrl}/${p.retailerImage!}')
                : null,
            child: p.retailerImage == null
                ? Text(
                    (p.retailerName?.isNotEmpty ?? false) ? p.retailerName![0].toUpperCase() : '?',
                    style: TextStyle(color: palette[1], fontWeight: FontWeight.bold, fontSize: 16),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.retailerName ?? 'Retailer #${p.retailerId}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: scheme.onSurface),
                      ),
                    ),
                    if (p.isBilled) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _kBilledAccent.withValues(alpha: isDark ? 0.22 : 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          t.t('billed'),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Color.lerp(_kBilledAccent, Colors.white, 0.25)! : _kBilledAccent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rs. ${p.amount.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: scheme.onSurface),
              ),
              if (isAdmin && !p.isBilled)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: () => _delete(p),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final isAdmin = ref.watch(authProvider).user!.isAdmin;
    final grouped = groupByDate<CashPayment>(_items, (p) => p.date, (d) => DateFormat('dd-MM-yyyy').format(d));

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kAccentBlue))
          : RefreshIndicator(
              color: _kAccentBlue,
              onRefresh: _load,
              child: _items.isEmpty
                  ? Center(
                      child: Text(
                        t.t('noPaymentsYet'),
                        style: TextStyle(color: scheme.outline),
                      ),
                    )
                  : SafeArea(
                    child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                        children: [
                          for (final entry in grouped.entries) ...[
                            dateGroupHeader(scheme, entry.key),
                            for (int i = 0; i < entry.value.length; i++)
                              _paymentCard(context, t, scheme, isAdmin, entry.value[i], _items.indexOf(entry.value[i])),
                          ],
                        ],
                      ),
                  ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kAccentBlue,
        onPressed: _openForm,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(t.t('newPayment'), style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}