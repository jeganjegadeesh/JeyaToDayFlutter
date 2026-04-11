import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/stock_provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/models/stock_model.dart';
import '../../widgets/common/app_layout.dart';

class RetailerStockHistoryScreen extends ConsumerStatefulWidget {
  const RetailerStockHistoryScreen({super.key});

  @override
  ConsumerState<RetailerStockHistoryScreen> createState() =>
      _State();
}

class _State extends ConsumerState<RetailerStockHistoryScreen> {
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final user = ref.read(authProvider).user;
    // Retailer: GET /retailer/stock  (same StockController.history, auth gives retailer_id)
    // The existing history endpoint already filters by auth when role=retailer,
    // but we pass retailer_id explicitly so admin can also use this screen safely.

    print('Fetching stock history with from: $_from, to: $_to for retailer_id: ${user?.id}');
    await ref.read(stockProvider.notifier).fetchHistory(
          retailerId: user?.id,
          fromDate: _from != null ? DateFormat('yyyy-MM-dd').format(_from!) : null,
          toDate:   _to   != null ? DateFormat('yyyy-MM-dd').format(_to!)   : null,
        );
  }

  Future<void> _pickFrom() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (p != null) { setState(() => _from = p); _load(); }
  }

  Future<void> _pickTo() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (p != null) { setState(() => _to = p); _load(); }
  }

  void _clear() { setState(() { _from = null; _to = null; }); _load(); }

  @override
  Widget build(BuildContext context) {
    final primary     = ref.watch(themeProvider).primaryColor;
    final state       = ref.watch(stockProvider);
    final isDesktop   = MediaQuery.of(context).size.width >= AppConstants.desktopBreakpoint;
    const color       = Color(0xFFE67E22);

    return AppLayout(
      title: 'Stock History',
      selectedIndex: 0,
      child: Column(
        children: [
          _FilterBar(
            from: _from, to: _to, color: color,
            onPickFrom: _pickFrom, onPickTo: _pickTo, onClear: _clear,
            isDesktop: isDesktop,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.entries.isEmpty
                      ? _Empty(icon: Icons.local_shipping_outlined, label: 'No stock entries found')
                      : ListView.builder(
                          padding: EdgeInsets.all(isDesktop ? 24 : 16),
                          itemCount: state.entries.length,
                          itemBuilder: (_, i) => _StockCard(
                              entry: state.entries[i], color: color, primary: primary),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stock Card ────────────────────────────────────────────────────────────────
class _StockCard extends StatelessWidget {
  final StockEntryModel entry;
  final Color color, primary;
  const _StockCard({required this.entry, required this.color, required this.primary});

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final totalQty = entry.items.fold<int>(0, (s, i) => s + i.quantity);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.local_shipping, color: color, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('dd MMM yyyy').format(DateTime.tryParse(entry.date) ?? DateTime.now()),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15,
                            color: isDark ? Colors.white : const Color(0xFF1E4D78)),
                      ),
                      Text('$totalQty items received',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ),
                _Badge(label: '$totalQty qty', color: color),
              ],
            ),
          ),
          // Products
          Padding(
            padding: const EdgeInsets.all(13),
            child: Wrap(
              spacing: 8, runSpacing: 8,
              children: entry.items.map((item) => _ProductChip(
                  name: item.product?.name ?? 'Product',
                  qty: item.quantity,
                  color: color,
                  isDark: isDark)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _ProductChip extends StatelessWidget {
  final String name;
  final int qty;
  final Color color;
  final bool isDark;
  const _ProductChip({required this.name, required this.qty, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text('$name × $qty',
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : const Color(0xFF2D3748))),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Empty({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 72, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text(label, style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[500])),
        const SizedBox(height: 8),
        Text('Pull down to refresh', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400])),
      ]),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final DateTime? from, to;
  final Color color;
  final VoidCallback onPickFrom, onPickTo, onClear;
  final bool isDesktop;

  const _FilterBar({
    required this.from, required this.to, required this.color,
    required this.onPickFrom, required this.onPickTo, required this.onClear,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F7FA),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16, vertical: 12),
      child: Row(
        children: [
          Expanded(child: _DateChip(
            label: from != null ? 'From: ${DateFormat('dd MMM').format(from!)}' : 'From Date',
            color: color, active: from != null, onTap: onPickFrom,
          )),
          const SizedBox(width: 10),
          Expanded(child: _DateChip(
            label: to != null ? 'To: ${DateFormat('dd MMM').format(to!)}' : 'To Date',
            color: color, active: to != null, onTap: onPickTo,
          )),
          if (from != null || to != null) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.clear, color: Colors.red, size: 20),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;
  const _DateChip({required this.label, required this.color, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? color : Colors.grey[300]!, width: 1.2),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_today, size: 13, color: active ? color : Colors.grey[500]),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500,
                    color: active ? color : Colors.grey[600]),
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }
}
