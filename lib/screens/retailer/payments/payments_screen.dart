import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/cash_payment.dart';
import '../../../services/retailer_portal_service.dart';
import '../../../services/api_service.dart';
import '../../../widgets/dialogs.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<CashPayment> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await RetailerPortalService.payments();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paid Amount')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? const Center(child: Text('No payments yet'))
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final p = _items[i];
                        return ListTile(
                          leading: const Icon(Icons.currency_rupee),
                          title: Text(DateFormat('dd-MM-yyyy').format(p.date)),
                          trailing: Text('Rs. ${p.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
            ),
    );
  }
}
