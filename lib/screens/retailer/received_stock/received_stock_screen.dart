import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/stock_entry.dart';
import '../../../services/retailer_portal_service.dart';
import '../../../services/api_service.dart';
import '../../../utils/num_format.dart';
import '../../../widgets/dialogs.dart';

const _kTeal = Color(0xFF0D9488);

class ReceivedStockScreen extends StatefulWidget {
  const ReceivedStockScreen({super.key});

  @override
  State<ReceivedStockScreen> createState() => _ReceivedStockScreenState();
}

class _ReceivedStockScreenState extends State<ReceivedStockScreen> {
  List<StockEntry> _items = [];
  bool _loading = true;
  final Set<int> _expanded = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await RetailerPortalService.receivedStock();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(int id) {
    setState(() {
      if (!_expanded.add(id)) _expanded.remove(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Received Stock')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No stock received yet')),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                      itemCount: _items.length,
                      itemBuilder: (_, i) => _entryCard(context, scheme, _items[i]),
                    ),
            ),
    );
  }

  Widget _entryCard(BuildContext context, ColorScheme scheme, StockEntry e) {
    final isOpen = _expanded.contains(e.id);
    final totalQty = e.items.fold<double>(0, (a, b) => a + b.quantity);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggle(e.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.move_to_inbox_outlined, color: scheme.onSurfaceVariant, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('dd-MM-yyyy').format(e.date),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${e.items.length} products \u00b7 Qty ${totalQty.qty}',
                          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: isOpen ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  child: Column(
                    children: [
                      for (final item in e.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.productName ?? 'Product #${item.productId}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: _kTeal,
                                  ),
                                ),
                              ),
                              Text(
                                item.quantity.qty,
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: scheme.onSurface),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}