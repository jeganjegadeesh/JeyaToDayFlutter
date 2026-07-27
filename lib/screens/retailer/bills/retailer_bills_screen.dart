import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/bill.dart';
import '../../../services/retailer_portal_service.dart';
import '../../../services/api_service.dart';
import '../../../widgets/bill_preview_card.dart';
import '../../../widgets/dialogs.dart';

class RetailerBillsScreen extends StatefulWidget {
  const RetailerBillsScreen({super.key});

  @override
  State<RetailerBillsScreen> createState() => _RetailerBillsScreenState();
}

class _RetailerBillsScreenState extends State<RetailerBillsScreen> {
  List<Bill> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await RetailerPortalService.bills();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _preview(Bill b) async {
    try {
      final full = await RetailerPortalService.billShow(b.id!);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          child: SizedBox(width: 500, child: SingleChildScrollView(child: BillPreviewCard(bill: full))),
        ),
      );
    } on ApiException catch (e) {
      showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Bills')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? const Center(child: Text('No bills yet'))
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final b = _items[i];
                        return ListTile(
                          leading: const Icon(Icons.receipt),
                          title: Text(DateFormat('dd-MM-yyyy').format(b.date)),
                          trailing: Text('Rs. ${b.settledAmount > 0 ? b.settledAmount.toStringAsFixed(2) : b.grandTotal.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          onTap: () => _preview(b),
                        );
                      },
                    ),
            ),
    );
  }
}
