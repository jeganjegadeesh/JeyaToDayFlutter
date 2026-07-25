import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/api_config.dart';
import '../config/network_url.dart';
import '../l10n/app_localizations.dart';
import '../models/product.dart';
import '../models/retailer.dart';
import '../models/stock_entry.dart';
import '../services/crud_service.dart';
import '../services/stock_service.dart';
import '../services/api_service.dart';
import '../utils/num_format.dart';
import 'dialogs.dart';

// Brand accent - stays constant across light/dark, everything else reads
// from Theme.of(context).colorScheme so the screen adapts automatically.
const _kAccentBlue = Color(0xFF3B82F6);

class StockFormPage extends StatefulWidget {
  final String titleKey; // 'giveStock' or 'returnStock'
  final String endpoint; // '/give-stock' or '/return-stock'
  final StockEntry? existing;

  const StockFormPage({super.key, required this.titleKey, required this.endpoint, this.existing});

  @override
  State<StockFormPage> createState() => _StockFormPageState();
}

class _StockFormPageState extends State<StockFormPage> {
  late final StockService _service = StockService(widget.endpoint);
  final _retailerService = CrudService<Retailer>(NetworkUrl.retailers, Retailer.fromJson);
  final _productService = CrudService<Product>(NetworkUrl.products, Product.fromJson);

  List<Retailer> _retailers = [];
  List<Product> _products = [];
  int? _retailerId;
  DateTime _date = DateTime.now();
  final Map<int, TextEditingController> _qtyControllers = {};
  final Set<int> _selectedProducts = {};
  bool _loading = true;
  bool _saving = false;

  /// This form is shared by both "Give Stock" and "Return Stock". Only the
  /// return-stock side needs the "don't return more than was given" check.
  bool get _isReturnStock => widget.endpoint == NetworkUrl.returnStock;

  // productId -> quantity still available to return (given so far, minus
  // whatever has already been returned and not yet billed). Only populated
  // for the return-stock form once a retailer is selected.
  Map<int, double> _availableToReturn = {};
  bool _loadingAvailability = false;

  Retailer? get _selectedRetailer {
    if (_retailerId == null) return null;
    for (final r in _retailers) {
      if (r.id == _retailerId) return r;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final results = await Future.wait([_retailerService.list(), _productService.list()]);
      _retailers = results[0] as List<Retailer>;
      _products = results[1] as List<Product>;
      for (final p in _products) {
        _qtyControllers[p.id] = TextEditingController();
      }

      if (widget.existing != null) {
        _retailerId = widget.existing!.retailerId;
        _date = widget.existing!.date;
        for (final item in widget.existing!.items) {
          if (item.productId != null) {
            _selectedProducts.add(item.productId!);
            _qtyControllers[item.productId!]?.text = item.quantity.qty;
          }
        }
      }
      await _loadAvailability();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickRetailer() async {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    String search = '';

    final picked = await showModalBottomSheet<int>(
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
                        autofocus: false,
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

    if (picked != null) {
      setState(() => _retailerId = picked);
      _loadAvailability();
    }
  }

  /// For the return-stock form: fetches how much of each product is still
  /// available to return for the selected retailer, i.e.
  /// (given so far) - (already returned), restricted to entries not yet
  /// billed (billed transactions are settled and no longer relevant).
  Future<void> _loadAvailability() async {
    if (!_isReturnStock || _retailerId == null) {
      setState(() => _availableToReturn = {});
      return;
    }
    setState(() => _loadingAvailability = true);
    try {
      final giveService = StockService(NetworkUrl.giveStock);
      final returnService = StockService(NetworkUrl.returnStock);
      final results = await Future.wait([
        giveService.list(retailerId: _retailerId, isBilled: false, perPage: 200),
        returnService.list(retailerId: _retailerId, isBilled: false, perPage: 200),
      ]);
      final given = results[0];
      final returned = results[1];

      final givenTotals = <int, double>{};
      for (final e in given) {
        for (final item in e.items) {
          if (item.productId == null) continue;
          givenTotals[item.productId!] = (givenTotals[item.productId!] ?? 0) + item.quantity;
        }
      }

      final returnedTotals = <int, double>{};
      for (final e in returned) {
        // Exclude the entry currently being edited so its own quantity
        // doesn't count against itself.
        if (widget.existing != null && e.id == widget.existing!.id) continue;
        for (final item in e.items) {
          if (item.productId == null) continue;
          returnedTotals[item.productId!] = (returnedTotals[item.productId!] ?? 0) + item.quantity;
        }
      }

      final available = <int, double>{
        for (final pid in givenTotals.keys) pid: givenTotals[pid]! - (returnedTotals[pid] ?? 0),
      };

      if (mounted) setState(() => _availableToReturn = available);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loadingAvailability = false);
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

  /// Inline validation message shown under a product's qty field on the
  /// return-stock form when the entered amount exceeds what's still
  /// available to return for that product.
  String? _returnQtyErrorText(int productId) {
    if (!_isReturnStock) return null;
    final entered = double.tryParse(_qtyControllers[productId]?.text ?? '');
    if (entered == null || entered <= 0) return null;
    final available = _availableToReturn[productId] ?? 0;
    if (entered > available) {
      final t = context.l10n;
      return '${t.t('maxAllowed')} ${available.qty}';
    }
    return null;
  }

  /// Shows what was given to this retailer (and how much of it is still
  /// available to return) so the person filling the return-stock form can
  /// see the ceiling for each product before typing a quantity.
  Widget _availabilityPanel(BuildContext context, AppLocalizations t, ColorScheme scheme) {
    const accent = Color(0xFF10B981);
    if (_loadingAvailability) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator(color: _kAccentBlue)),
      );
    }

    final entries = _availableToReturn.entries.where((e) => e.value > 0).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 16, color: accent),
              const SizedBox(width: 8),
              Text(
                t.t('givenStockAvailable'),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: accent),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            Text(t.t('noGivenStockFound'), style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entries.map((e) {
                Product? product;
                for (final p in _products) {
                  if (p.id == e.key) {
                    product = p;
                    break;
                  }
                }
                final name = product?.name ?? 'Product #${e.key}';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
                  child: Text('$name · ${e.value.qty}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accent)),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  bool _hasReturnValidationErrors() {
    if (!_isReturnStock) return false;
    for (final pid in _selectedProducts) {
      if (_returnQtyErrorText(pid) != null) return true;
    }
    return false;
  }

  Future<void> _save() async {
    final t = context.l10n;
    if (_retailerId == null) {
      showSnack(context, t.t('selectRetailerError'), isError: true);
      return;
    }
    final items = _selectedProducts.map((pid) {
      final qty = double.tryParse(_qtyControllers[pid]!.text) ?? 0;
      return {'product_id': pid, 'quantity': qty};
    }).where((e) => (e['quantity'] as double) > 0).toList();

    if (items.isEmpty) {
      showSnack(context, t.t('selectProductQtyError'), isError: true);
      return;
    }

    if (_isReturnStock) {
      for (final item in items) {
        final pid = item['product_id'] as int;
        final qty = item['quantity'] as double;
        final available = _availableToReturn[pid] ?? 0;
        if (qty > available) {
          Product? product;
          for (final p in _products) {
            if (p.id == pid) {
              product = p;
              break;
            }
          }
          final name = product?.name ?? 'Product #$pid';
          showSnack(context, '$name: ${t.t('maxAllowed')} ${available.qty}', isError: true);
          return;
        }
      }
    }

    setState(() => _saving = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_date);
      if (widget.existing == null) {
        await _service.create(retailerId: _retailerId!, date: dateStr, items: items);
      } else {
        await _service.update(widget.existing!.id, date: dateStr, items: items);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final title = t.t(widget.titleKey);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: CircularProgressIndicator(color: _kAccentBlue)),
      );
    }

    final retailer = _selectedRetailer;
    final retailerPalette = retailer != null ? _avatarPalette(context, _retailers.indexOf(retailer)) : null;

    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? '${t.t('newEntry')} · $title' : '${t.t('editEntry')} · $title')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(t.t('retailer'), style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _pickRetailer,
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
                    backgroundColor: retailerPalette?[0] ?? scheme.surfaceContainerHighest,
                    backgroundImage: retailer?.profileImage != null
                        ? NetworkImage('${ApiConfig.imageBaseUrl}/${retailer!.profileImage!}')
                        : null,
                    child: retailer == null
                        ? Icon(Icons.storefront_outlined, size: 18, color: scheme.onSurfaceVariant)
                        : (retailer.profileImage == null
                            ? Text(
                                retailer.name.isNotEmpty ? retailer.name[0].toUpperCase() : '?',
                                style: TextStyle(color: retailerPalette?[1], fontWeight: FontWeight.bold),
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
          const SizedBox(height: 18),
          Text(t.t('date'), style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _pickDate,
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
                  Text(DateFormat('dd-MM-yyyy').format(_date), style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          if (_isReturnStock && _retailerId != null) ...[
            _availabilityPanel(context, t, scheme),
            const SizedBox(height: 18),
          ],
          Text(t.t('products'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurface)),
          const SizedBox(height: 10),
          ..._products.map((p) {
            final selected = _selectedProducts.contains(p.id);
            final available = _availableToReturn[p.id];
            final errorText = selected ? _returnQtyErrorText(p.id) : null;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? _kAccentBlue.withValues(alpha: 0.08) : scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: errorText != null
                      ? Colors.red.shade300
                      : (selected ? _kAccentBlue.withValues(alpha: 0.4) : scheme.outlineVariant),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: selected,
                        activeColor: _kAccentBlue,
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _selectedProducts.add(p.id);
                          } else {
                            _selectedProducts.remove(p.id);
                          }
                        }),
                      ),
                      Expanded(
                        child: Text(
                          p.name,
                          style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
                        ),
                      ),
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: _qtyControllers[p.id],
                          enabled: selected,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: t.t('qty'),
                            isDense: true,
                            filled: true,
                            fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isReturnStock && (available != null && available > 0))
                    Padding(
                      padding: const EdgeInsets.only(left: 48, bottom: 4),
                      child: Text(
                        '${t.t('availableToReturn')}: ${available.qty}',
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 48, bottom: 6),
                      child: Text(
                        errorText,
                        style: TextStyle(fontSize: 11.5, color: Colors.red.shade700, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: (_saving || _hasReturnValidationErrors()) ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: _kAccentBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(t.t('save')),
          ),
        ],
      ),
    );
  }
}