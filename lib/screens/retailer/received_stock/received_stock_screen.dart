import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/stock_entry.dart';
import '../../../services/retailer_portal_service.dart';
import '../../../services/api_service.dart';
import '../../../utils/num_format.dart';
import '../../../widgets/dialogs.dart';

class ReceivedStockScreen extends StatefulWidget {
  const ReceivedStockScreen({super.key});

  @override
  State<ReceivedStockScreen> createState() => _ReceivedStockScreenState();
}

class _ReceivedStockScreenState extends State<ReceivedStockScreen> {
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
      _items = await RetailerPortalService.receivedStock();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _preview(StockEntry e) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(DateFormat('dd-MM-yyyy').format(e.date)),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: e.items
                .map((i) => ListTile(dense: true, title: Text(i.productName ?? ''), trailing: Text(i.quantity.qty)))
                .toList(),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Received Stock')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? const Center(child: Text('No stock received yet'))
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final e = _items[i];
                        final totalQty = e.items.fold<double>(0, (a, b) => a + b.quantity);
                        return ListTile(
                          leading: const Icon(Icons.move_to_inbox),
                          title: Text(DateFormat('dd-MM-yyyy').format(e.date)),
                          subtitle: Text('${e.items.length} products · Qty ${totalQty.qty}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _preview(e),
                        );
                      },
                    ),
            ),
    );
  }
}