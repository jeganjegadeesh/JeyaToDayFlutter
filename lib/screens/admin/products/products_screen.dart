import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/network_url.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/product.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/crud_service.dart';
import '../../../services/api_service.dart';
import '../../../widgets/dialogs.dart';

// Brand accent - stays constant across light/dark, everything else reads
// from Theme.of(context).colorScheme so the screen adapts automatically.
const _kAccentBlue = Color(0xFF3B82F6);

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _service = CrudService<Product>(NetworkUrl.products, Product.fromJson);
  List<Product> _items = [];
  bool _loading = true;
  String _search = '';
  String? _typeFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _service.list(query: {
        if (_search.isNotEmpty) 'search': _search,
        if (_typeFilter != null) 'type': _typeFilter,
      });
      setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openForm({Product? existing}) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final rateCtrl = TextEditingController(text: existing?.rate.toString() ?? '');
    String type = existing?.type ?? 'retail';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            existing == null ? t.t('addProduct') : t.t('editProduct'),
            style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: _fieldDecoration(context, t.t('name'), Icons.inventory_2_outlined),
                    validator: (v) => (v == null || v.isEmpty) ? t.t('required') : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: _fieldDecoration(context, t.t('type'), Icons.category_outlined),
                    items: [
                      DropdownMenuItem(value: 'retail', child: Text(t.t('retail'))),
                      DropdownMenuItem(value: 'bulk', child: Text(t.t('bulk'))),
                      DropdownMenuItem(value: 'both', child: Text(t.t('both'))),
                    ],
                    onChanged: (v) => setDialogState(() => type = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: rateCtrl,
                    decoration: _fieldDecoration(context, t.t('rate'), Icons.currency_rupee),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => (v == null || double.tryParse(v) == null) ? t.t('validNumber') : null,
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
                if (!formKey.currentState!.validate()) return;
                final body = {
                  'name': nameCtrl.text.trim(),
                  'type': type,
                  'rate': double.parse(rateCtrl.text),
                };
                try {
                  if (existing == null) {
                    await _service.create(body);
                  } else {
                    await _service.update(existing.id, body);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } on ApiException catch (e) {
                  showSnack(ctx, e.message, isError: true);
                }
              },
              child: Text(t.t('save')),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(BuildContext context, String label, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: scheme.onSurfaceVariant),
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _delete(Product p) async {
    final t = context.l10n;
    final ok = await confirmDialog(
      context,
      title: t.t('deleteProduct'),
      message: '${t.t('deleteProductConfirm')} "${p.name}"',
    );
    if (!ok) return;
    try {
      await _service.delete(p.id);
      _load();
    } on ApiException catch (e) {
      showSnack(context, e.message, isError: true);
    }
  }

  // ---- Style helpers - theme aware so light & dark both work ----

  Color _typeAccent(String type) {
    switch (type) {
      case 'bulk':
        return const Color(0xFFF59E0B);
      case 'both':
        return const Color(0xFF8B5CF6);
      default:
        return _kAccentBlue;
    }
  }

  Color _badgeBg(BuildContext context, String type) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _typeAccent(type).withValues(alpha: isDark ? 0.22 : 0.12);
  }

  Color _badgeText(BuildContext context, String type) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = _typeAccent(type);
    return isDark ? Color.lerp(base, Colors.white, 0.25)! : base;
  }

  String _typeLabel(BuildContext context, String type) {
    final t = context.l10n;
    switch (type) {
      case 'bulk':
        return t.t('bulk');
      case 'both':
        return t.t('both');
      default:
        return t.t('retail');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final isAdmin = ref.watch(authProvider).user!.isAdmin;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: _kAccentBlue,
        shape: const CircleBorder(),
        onPressed: () => _openForm(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: t.t('searchByProductName'),
                hintStyle: TextStyle(color: scheme.outline),
                prefixIcon: Icon(Icons.search, color: scheme.outline),
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
              onSubmitted: (v) {
                _search = v;
                _load();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip(context, label: t.t('all'), value: null),
                  const SizedBox(width: 10),
                  _filterChip(context, label: t.t('retail'), value: 'retail'),
                  const SizedBox(width: 10),
                  _filterChip(context, label: t.t('bulk'), value: 'bulk'),
                  const SizedBox(width: 10),
                  _filterChip(context, label: t.t('both'), value: 'both'),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kAccentBlue))
                : _items.isEmpty
                    ? Center(
                        child: Text(
                          t.t('noProductsFound'),
                          style: TextStyle(color: scheme.outline),
                        ),
                      )
                    : RefreshIndicator(
                        color: _kAccentBlue,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                          itemCount: _items.length,
                          itemBuilder: (_, i) {
                            final p = _items[i];
                            final accent = _typeAccent(p.type);
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
                                    backgroundColor: accent.withValues(alpha: isDark ? 0.28 : 0.15),
                                    child: Icon(Icons.inventory_2_outlined, color: accent, size: 20),
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
                                                p.name,
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
                                                color: _badgeBg(context, p.type),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                _typeLabel(context, p.type),
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: _badgeText(context, p.type),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(Icons.currency_rupee, size: 13, color: scheme.outline),
                                            Text(
                                              p.rate.toStringAsFixed(2),
                                              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert, color: scheme.outline),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    onSelected: (v) {
                                      if (v == 'edit') _openForm(existing: p);
                                      if (v == 'delete') _delete(p);
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
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(BuildContext context, {required String label, required String? value}) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _typeFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _typeFilter = value);
        _load();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _kAccentBlue : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? Colors.transparent : scheme.outlineVariant),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}