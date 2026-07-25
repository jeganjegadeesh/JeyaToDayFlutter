import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';
import '../l10n/app_localizations.dart';
import '../models/stock_entry.dart';
import '../providers/auth_provider.dart';
import '../services/stock_service.dart';
import '../services/api_service.dart';
import '../utils/num_format.dart';
import 'date_group_header.dart';
import 'dialogs.dart';
import 'stock_form_page.dart';

// Brand accent - stays constant across light/dark, everything else reads
// from Theme.of(context).colorScheme so the screen adapts automatically.
const _kAccentBlue = Color(0xFF3B82F6);
const _kBilledAccent = Color(0xFF10B981);
const _kPendingAccent = Color(0xFFF59E0B);

/// Shared history screen used for both "Give Stock" and "Return Stock".
/// [titleKey] is a localization key (e.g. 'giveStock' / 'returnStock') so the
/// title, empty state, and FAB label are all translated automatically.
class StockHistoryPage extends ConsumerStatefulWidget {
  final String titleKey;
  final String endpoint;

  const StockHistoryPage({super.key, required this.titleKey, required this.endpoint});

  @override
  ConsumerState<StockHistoryPage> createState() => _StockHistoryPageState();
}

class _StockHistoryPageState extends ConsumerState<StockHistoryPage> {
  late final StockService _service = StockService(widget.endpoint);
  List<StockEntry> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _service.list();
      items.sort((a, b) => b.date.compareTo(a.date));
      setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNew({StockEntry? existing}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => StockFormPage(titleKey: widget.titleKey, endpoint: widget.endpoint, existing: existing),
      ),
    );
    if (result == true) _load();
  }

  void _preview(StockEntry e) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '${e.retailerName ?? ''} · ${DateFormat('dd-MM-yyyy').format(e.date)}',
          style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: e.items
                  .map(
                    (i) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              i.productName ?? 'Product #${i.productId}',
                              style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _kAccentBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              i.quantity.qty,
                              style: const TextStyle(color: _kAccentBlue, fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t.t('close'), style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(StockEntry e) async {
    final t = context.l10n;
    final ok = await confirmDialog(context, title: t.t('deleteEntry'), message: t.t('deleteEntryConfirm'));
    if (!ok) return;
    try {
      await _service.delete(e.id);
      _load();
    } on ApiException catch (ex) {
      showSnack(context, ex.message, isError: true);
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

  Widget _entryCard(BuildContext context, AppLocalizations t, ColorScheme scheme, bool isAdmin, StockEntry e, int seed) {
    final palette = _avatarPalette(context, seed);
    final totalQty = e.items.fold<double>(0, (a, b) => a + b.quantity);
    final statusAccent = e.isBilled ? _kBilledAccent : _kPendingAccent;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _preview(e),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: palette[0],
                    backgroundImage: e.retailerImage != null
                        ? NetworkImage('${ApiConfig.imageBaseUrl}/${e.retailerImage!}')
                        : null,
                    child: e.retailerImage == null
                        ? Text(
                            (e.retailerName?.isNotEmpty ?? false) ? e.retailerName![0].toUpperCase() : '?',
                            style: TextStyle(
                              color: palette[1],
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: -1,
                    right: -1,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: statusAccent.withValues(alpha: isDark ? 0.9 : 1),
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.surfaceContainerLow, width: 2),
                      ),
                      child: Icon(
                        e.isBilled ? Icons.check : Icons.schedule,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
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
                            e.retailerName ?? 'Retailer #${e.retailerId}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusAccent.withValues(alpha: isDark ? 0.22 : 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            e.isBilled ? t.t('billed') : t.t('pending'),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Color.lerp(statusAccent, Colors.white, 0.25)!
                                  : statusAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 12, color: scheme.outline),
                        const SizedBox(width: 4),
                        Text(
                          '${e.items.length} · Qty ${totalQty.qty}',
                          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!e.isBilled)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: scheme.outline),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (v) {
                    if (v == 'edit') _openNew(existing: e);
                    if (v == 'delete') _delete(e);
                  },
                  itemBuilder: (menuCtx) {
                    final menuScheme = Theme.of(menuCtx).colorScheme;
                    return [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18, color: menuScheme.onSurfaceVariant),
                            const SizedBox(width: 10),
                            Text(t.t('edit')),
                          ],
                        ),
                      ),
                      if (isAdmin)
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                              const SizedBox(width: 10),
                              Text(t.t('delete'), style: const TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                    ];
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final isAdmin = ref.watch(authProvider).user!.isAdmin;
    final grouped = groupByDate<StockEntry>(_items, (e) => e.date, (d) => DateFormat('dd-MM-yyyy').format(d));

    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('history')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kAccentBlue))
          : RefreshIndicator(
              color: _kAccentBlue,
              onRefresh: _load,
              child: _items.isEmpty
                  ? Center(
                      child: Text(
                        t.t('noEntriesYet'),
                        style: TextStyle(color: scheme.outline),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                      children: [
                        for (final entry in grouped.entries) ...[
                          dateGroupHeader(scheme, entry.key),
                          for (int i = 0; i < entry.value.length; i++)
                            _entryCard(context, t, scheme, isAdmin, entry.value[i], _items.indexOf(entry.value[i])),
                        ],
                      ],
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kAccentBlue,
        onPressed: () => _openNew(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(t.t('newEntry'), style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}