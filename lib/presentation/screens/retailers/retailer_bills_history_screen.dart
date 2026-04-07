import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/bill_provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../data/models/bill_model.dart';
import '../../widgets/common/app_layout.dart';

class RetailerBillsHistoryScreen extends ConsumerStatefulWidget {
  const RetailerBillsHistoryScreen({super.key});

  @override
  ConsumerState<RetailerBillsHistoryScreen> createState() => _State();
}

class _State extends ConsumerState<RetailerBillsHistoryScreen> {
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final user = ref.read(authProvider).user;
    await ref.read(billProvider.notifier).fetchHistory(
          retailerId: user?.id,
          fromDate: _from != null ? DateFormat('yyyy-MM-dd').format(_from!) : null,
          toDate:   _to   != null ? DateFormat('yyyy-MM-dd').format(_to!)   : null,
        );
  }

  Future<void> _pickFrom() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2024), lastDate: DateTime.now(),
    );
    if (p != null) { setState(() => _from = p); _load(); }
  }

  Future<void> _pickTo() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: DateTime(2024), lastDate: DateTime.now(),
    );
    if (p != null) { setState(() => _to = p); _load(); }
  }

  void _clear() { setState(() { _from = null; _to = null; }); _load(); }

  @override
  Widget build(BuildContext context) {
    final primary   = ref.watch(themeProvider).primaryColor;
    final state     = ref.watch(billProvider);
    final isDesktop = MediaQuery.of(context).size.width >= AppConstants.desktopBreakpoint;
    const color     = Color(0xFF8E44AD);

    return AppLayout(
      title: 'Bills History',
      selectedIndex: 0,
      child: Column(
        children: [
          _FilterBar(
            from: _from, to: _to, color: color,
            onPickFrom: _pickFrom, onPickTo: _pickTo, onClear: _clear,
            isDesktop: isDesktop,
          ),
          // Summary strip
          if (!state.isLoading && state.bills.isNotEmpty)
            _SummaryStrip(bills: state.bills, color: color),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: state.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : state.bills.isEmpty
                      ? _Empty()
                      : ListView.builder(
                          padding: EdgeInsets.all(isDesktop ? 24 : 16),
                          itemCount: state.bills.length,
                          itemBuilder: (_, i) =>
                              _BillCard(bill: state.bills[i], color: color, primary: primary),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Summary Strip ─────────────────────────────────────────────────────────────
class _SummaryStrip extends StatelessWidget {
  final List<BillModel> bills;
  final Color color;
  const _SummaryStrip({required this.bills, required this.color});

  @override
  Widget build(BuildContext context) {
    final totalSales   = bills.fold<double>(0, (s, b) => s + b.totalSales);
    final totalFinal   = bills.fold<double>(0, (s, b) => s + b.finalAmount);
    final totalBalance = bills.fold<double>(0, (s, b) => s + b.balanceAmount);
    final fmt          = NumberFormat('#,##0.00');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SumItem(label: 'Total Sales', value: '₹${fmt.format(totalSales)}', color: color),
          Container(height: 32, width: 1, color: Colors.grey[200]),
          _SumItem(label: 'Final Amt',   value: '₹${fmt.format(totalFinal)}',   color: const Color(0xFF27AE60)),
          Container(height: 32, width: 1, color: Colors.grey[200]),
          _SumItem(label: 'Balance',     value: '₹${fmt.format(totalBalance)}',
              color: totalBalance > 0 ? const Color(0xFFE74C3C) : const Color(0xFF27AE60)),
        ],
      ),
    );
  }
}

class _SumItem extends StatelessWidget {
  final String label, value; final Color color;
  const _SumItem({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500])),
  ]);
}

// ── Bill Card ─────────────────────────────────────────────────────────────────
class _BillCard extends StatefulWidget {
  final BillModel bill;
  final Color color, primary;
  const _BillCard({required this.bill, required this.color, required this.primary});
  @override
  State<_BillCard> createState() => _BillCardState();
}

class _BillCardState extends State<_BillCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bill    = widget.bill;
    final color   = widget.color;
    final fmt     = NumberFormat('#,##0.00');
    final hasDue  = bill.balanceAmount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // ── Header ──
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: _expanded
                ? const BorderRadius.vertical(top: Radius.circular(14))
                : BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: color.withOpacity(0.06),
                borderRadius: _expanded
                    ? const BorderRadius.vertical(top: Radius.circular(14))
                    : BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.receipt_long, color: color, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bill #${bill.id}',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15,
                                color: isDark ? Colors.white : const Color(0xFF1E4D78))),
                        Text(
                          bill.fromDate != null && bill.toDate != null
                              ? '${DateFormat('dd MMM').format(DateTime.parse(bill.fromDate!))} – ${DateFormat('dd MMM yy').format(DateTime.parse(bill.toDate!))}'
                              : DateFormat('dd MMM yyyy').format(DateTime.tryParse(bill.date) ?? DateTime.now()),
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  // Paid / Due badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasDue
                          ? Colors.red.withOpacity(0.1)
                          : const Color(0xFF27AE60).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      hasDue ? 'Due ₹${fmt.format(bill.balanceAmount)}' : 'Paid',
                      style: GoogleFonts.poppins(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: hasDue ? Colors.red : const Color(0xFF27AE60)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.grey[400]),
                ],
              ),
            ),
          ),

          // ── Expanded ──
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // Amount tiles
                  Row(children: [
                    _AmtTile(label: 'Total Sales', value: '₹${fmt.format(bill.totalSales)}', color: const Color(0xFF2E75B6)),
                    _AmtTile(label: 'Commission',  value: '₹${fmt.format(bill.commission)}',  color: const Color(0xFFE67E22)),
                    _AmtTile(label: 'Final Amt',   value: '₹${fmt.format(bill.finalAmount)}', color: const Color(0xFF27AE60)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    _AmtTile(label: 'Paid',    value: '₹${fmt.format(bill.paidAmount)}',    color: const Color(0xFF27AE60)),
                    _AmtTile(label: 'Balance', value: '₹${fmt.format(bill.balanceAmount)}',
                        color: hasDue ? const Color(0xFFE74C3C) : Colors.grey),
                    const Expanded(child: SizedBox()),
                  ]),
                  if (bill.items.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 6),
                    // Table header
                    Row(children: [
                      _TH('Product',  flex: 3),
                      _TH('Given',    textAlign: TextAlign.center),
                      _TH('Ret',      textAlign: TextAlign.center),
                      _TH('Sold',     textAlign: TextAlign.center),
                      _TH('Amount',   textAlign: TextAlign.right),
                    ]),
                    const SizedBox(height: 4),
                    ...bill.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Expanded(flex: 3, child: Text(item.product?.name ?? 'Product',
                            style: GoogleFonts.poppins(fontSize: 12,
                                color: isDark ? Colors.white70 : const Color(0xFF2D3748)))),
                        Expanded(child: Text('${item.givenQty}',   textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]))),
                        Expanded(child: Text('${item.returnedQty}', textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]))),
                        Expanded(child: Text('${item.soldQty}', textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: color))),
                        Expanded(child: Text('₹${fmt.format(item.amount)}', textAlign: TextAlign.right,
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600,
                                color: const Color(0xFF27AE60)))),
                      ]),
                    )),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AmtTile extends StatelessWidget {
  final String label, value; final Color color;
  const _AmtTile({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.07), borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: GoogleFonts.poppins(fontSize: 9, color: Colors.grey[500])),
      ])));
}

class _TH extends StatelessWidget {
  final String text; final int flex; final TextAlign textAlign;
  const _TH(this.text, {this.flex = 1, this.textAlign = TextAlign.left});
  @override
  Widget build(BuildContext context) => Expanded(flex: flex,
      child: Text(text, textAlign: textAlign,
          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500])));
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.receipt_long_outlined, size: 72, color: Colors.grey[300]),
      const SizedBox(height: 16),
      Text('No bills found', style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[500])),
      const SizedBox(height: 8),
      Text('Pull down to refresh', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[400])),
  ]));
}

// ── Filter Bar ────────────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  final DateTime? from, to; final Color color;
  final VoidCallback onPickFrom, onPickTo, onClear; final bool isDesktop;
  const _FilterBar({required this.from, required this.to, required this.color,
      required this.onPickFrom, required this.onPickTo, required this.onClear, required this.isDesktop});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F7FA),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16, vertical: 12),
      child: Row(children: [
        Expanded(child: _DateChip(label: from != null ? 'From: ${DateFormat('dd MMM').format(from!)}' : 'From Date',
            color: color, active: from != null, onTap: onPickFrom)),
        const SizedBox(width: 10),
        Expanded(child: _DateChip(label: to != null ? 'To: ${DateFormat('dd MMM').format(to!)}' : 'To Date',
            color: color, active: to != null, onTap: onPickTo)),
        if (from != null || to != null) ...[
          const SizedBox(width: 10),
          GestureDetector(onTap: onClear,
            child: Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.clear, color: Colors.red, size: 20))),
        ],
      ]),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label; final Color color; final bool active; final VoidCallback onTap;
  const _DateChip({required this.label, required this.color, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: active ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? color : Colors.grey[300]!, width: 1.2)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.calendar_today, size: 13, color: active ? color : Colors.grey[500]),
        const SizedBox(width: 6),
        Flexible(child: Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500,
            color: active ? color : Colors.grey[600]), overflow: TextOverflow.ellipsis)),
      ]),
    ));
}
