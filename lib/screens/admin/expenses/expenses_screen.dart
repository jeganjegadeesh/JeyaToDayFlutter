import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/network_url.dart';
import '../../../models/misc_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/crud_service.dart';
import '../../../services/api_service.dart';
import '../../../widgets/date_group_header.dart';
import '../../../widgets/dialogs.dart';

// Brand accent - stays constant across light/dark, everything else reads
// from Theme.of(context).colorScheme so the screen adapts automatically.
const _kAccentBlue = Color(0xFF3B82F6);

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  final _expenseService = CrudService<Expense>(NetworkUrl.expenses, Expense.fromJson);
  final _rawMaterialService = CrudService<RawMaterial>(NetworkUrl.rawMaterials, RawMaterial.fromJson);
  List<Expense> _items = [];
  List<RawMaterial> _rawMaterials = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([_expenseService.list(), _rawMaterialService.list()]);
      final items = results[0] as List<Expense>;
      items.sort((a, b) => b.date.compareTo(a.date));
      _items = items;
      _rawMaterials = results[1] as List<RawMaterial>;
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openForm() {
    DateTime date = DateTime.now();
    final amountCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    final selected = <int>{};
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('New Expense'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerLeft, child: Text('Raw Materials', style: Theme.of(ctx).textTheme.labelLarge)),
                  Wrap(
                    spacing: 6,
                    children: _rawMaterials
                        .map((m) => FilterChip(
                              label: Text(m.name),
                              selected: selected.contains(m.id),
                              onSelected: (v) => setDialogState(() {
                                if (v) {
                                  selected.add(m.id);
                                } else {
                                  selected.remove(m.id);
                                }
                              }),
                            ))
                        .toList(),
                  ),
                  TextFormField(
                    controller: amountCtrl,
                    decoration: const InputDecoration(labelText: 'Amount (Rs.)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => (v == null || double.tryParse(v) == null) ? 'Enter a valid amount' : null,
                  ),
                  TextFormField(
                    controller: remarksCtrl,
                    decoration: const InputDecoration(labelText: 'Remarks (optional)'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _kAccentBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate() || selected.isEmpty) {
                  showSnack(ctx, 'Select at least one raw material', isError: true);
                  return;
                }
                try {
                  await _expenseService.create({
                    'date': DateFormat('yyyy-MM-dd').format(date),
                    'raw_material_ids': selected.toList(),
                    'amount': double.parse(amountCtrl.text),
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

  Future<void> _delete(Expense e) async {
    final ok = await confirmDialog(context, title: 'Delete Expense', message: 'Delete this expense?');
    if (!ok) return;
    try {
      await _expenseService.delete(e.id);
      _load();
    } on ApiException catch (ex) {
      showSnack(context, ex.message, isError: true);
    }
  }

  Widget _expenseCard(BuildContext context, ColorScheme scheme, bool isAdmin, Expense e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: scheme.shadow.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _kAccentBlue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.shopping_bag_outlined, size: 20, color: _kAccentBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.rawMaterials.map((m) => m.name).join(', '),
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: scheme.onSurface),
                ),
                if (e.remarks != null && e.remarks!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(e.remarks!, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rs. ${e.amount.toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: scheme.onSurface),
              ),
              if (isAdmin)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: () => _delete(e),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAdmin = ref.watch(authProvider).user!.isAdmin;
    final grouped = groupByDate<Expense>(_items, (e) => e.date, (d) => DateFormat('dd-MM-yyyy').format(d));

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kAccentBlue))
          : RefreshIndicator(
              color: _kAccentBlue,
              onRefresh: _load,
              child: _items.isEmpty
                  ? Center(child: Text('No expenses yet', style: TextStyle(color: scheme.outline)))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                      children: [
                        for (final entry in grouped.entries) ...[
                          dateGroupHeader(scheme, entry.key),
                          for (final e in entry.value) _expenseCard(context, scheme, isAdmin, e),
                        ],
                      ],
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kAccentBlue,
        onPressed: _openForm,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Expense', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}