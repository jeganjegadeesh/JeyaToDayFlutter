import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/network_url.dart';
import '../../../models/misc_models.dart';
import '../../../models/retailer.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/crud_service.dart';
import '../../../services/api_service.dart';
import '../../../widgets/dialogs.dart';

class RetailerLoansScreen extends ConsumerStatefulWidget {
  const RetailerLoansScreen({super.key});

  @override
  ConsumerState<RetailerLoansScreen> createState() => _RetailerLoansScreenState();
}

class _RetailerLoansScreenState extends ConsumerState<RetailerLoansScreen> {
  final _loanService = CrudService<RetailerLoan>(NetworkUrl.retailerLoans, RetailerLoan.fromJson);
  final _retailerService = CrudService<Retailer>(NetworkUrl.retailers, Retailer.fromJson);
  List<RetailerLoan> _items = [];
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
      final results = await Future.wait([_loanService.list(), _retailerService.list()]);
      _items = results[0] as List<RetailerLoan>;
      _retailers = results[1] as List<Retailer>;
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openForm() {
    int? retailerId;
    DateTime date = DateTime.now();
    final amountCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Retailer Loan'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Retailer'),
                  items: _retailers.map((r) => DropdownMenuItem(value: r.id, child: Text(r.name))).toList(),
                  onChanged: (v) => setDialogState(() => retailerId = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                TextFormField(
                  controller: amountCtrl,
                  decoration: const InputDecoration(labelText: 'Amount (Rs.)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter a valid amount' : null,
                ),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime(2100));
                    if (picked != null) setDialogState(() => date = picked);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date'),
                    child: Text(DateFormat('dd-MM-yyyy').format(date)),
                  ),
                ),
                TextFormField(
                  controller: remarksCtrl,
                  decoration: const InputDecoration(labelText: 'Remarks (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate() || retailerId == null) return;
                try {
                  await _loanService.create({
                    'retailer_id': retailerId,
                    'amount': double.parse(amountCtrl.text),
                    'date': DateFormat('yyyy-MM-dd').format(date),
                    'remarks': remarksCtrl.text.isEmpty ? null : remarksCtrl.text,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } on ApiException catch (e) {
                  showSnack(ctx, e.message, isError: true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(RetailerLoan l) async {
    final ok = await confirmDialog(context, title: 'Delete Loan', message: 'Delete this loan entry?');
    if (!ok) return;
    try {
      await _loanService.delete(l.id);
      _load();
    } on ApiException catch (e) {
      showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(authProvider).user!.isAdmin;

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? const Center(child: Text('No loans yet'))
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final l = _items[i];
                        return ListTile(
                          leading: const Icon(Icons.account_balance_wallet_outlined),
                          title: Text(l.retailerName ?? 'Retailer #${l.retailerId}'),
                          subtitle: Text('${DateFormat('dd-MM-yyyy').format(l.date)}${l.remarks != null ? ' · ${l.remarks}' : ''}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Rs. ${l.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              if (isAdmin)
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _delete(l)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _openForm, icon: const Icon(Icons.add), label: const Text('New Loan')),
    );
  }
}
