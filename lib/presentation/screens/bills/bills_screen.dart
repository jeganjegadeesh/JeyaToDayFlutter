import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../data/models/bill_model.dart';
import '../../../data/models/cash_payment_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/bill_provider.dart';
import '../../../data/providers/cash_payment_provider.dart';
import '../../../data/providers/retailer_provider.dart';
import '../../../data/providers/stock_provider.dart';
import '../../../data/providers/return_provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../widgets/common/app_layout.dart';
import 'bill_print_service.dart';

class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});

  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  UserModel? _selectedRetailer;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _toDate = DateTime.now();
  bool _loadingDates = false;
  double _previewPaidAmount = 0;
  List<CashPaymentModel> _previewPayments = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.microtask(() {
      ref.read(retailerProvider.notifier).fetchRetailers();
      ref.read(billProvider.notifier).fetchHistory();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Auto load date range when retailer selected
  Future<void> _onRetailerSelected(UserModel retailer) async {
    setState(() {
      _selectedRetailer = retailer;
      _loadingDates = true;
      _previewPaidAmount = 0;
      _previewPayments = [];
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/bill/last-date/${retailer.id}');
      final fromDate = response.data['from_date'];
      final toDate = response.data['to_date'];

      if (fromDate != null) {
        setState(() {
          _fromDate = DateTime.parse(fromDate);
          _toDate = DateTime.parse(toDate);
        });
        // Load cash payments for this period
        await _loadCashPayments();
      }
    } catch (e) {
      // Use default dates
    } finally {
      setState(() => _loadingDates = false);
    }
  }

  Future<void> _loadCashPayments() async {
    if (_selectedRetailer == null) return;
    final result = await ref.read(cashPaymentProvider.notifier).getTotal(
          retailerId: _selectedRetailer!.id,
          fromDate: DateFormat('yyyy-MM-dd').format(_fromDate),
          toDate: DateFormat('yyyy-MM-dd').format(_toDate),
        );
    setState(() {
      _previewPaidAmount = result['total'] as double;
      _previewPayments = result['payments'] as List<CashPaymentModel>;
    });
  }

  Future<void> _selectFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _fromDate = picked);
      await _loadCashPayments();
    }
  }

  Future<void> _selectToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _toDate = picked);
      await _loadCashPayments();
    }
  }

  Future<void> _generateBill() async {
    if (_selectedRetailer == null) {
      _showError('Please select a retailer');
      return;
    }
    if (_fromDate.isAfter(_toDate)) {
      _showError('From date must be before To date');
      return;
    }

    final success = await ref.read(billProvider.notifier).generateBill(
          retailerId: _selectedRetailer!.id,
          fromDate: DateFormat('yyyy-MM-dd').format(_fromDate),
          toDate: DateFormat('yyyy-MM-dd').format(_toDate),
        );

    if (success && mounted) {
      final bill = ref.read(billProvider).currentBill;
      if (bill != null) {
        await _loadAndShowBillDetail(bill);
      }
      ref.read(billProvider.notifier).fetchHistory();
      _tabController.animateTo(2);
    } else if (mounted) {
      _showError(ref.read(billProvider).error ?? 'Something went wrong');
    }
  }

  // Cash payment dialog
  void _showCashPaymentDialog() {
    if (_selectedRetailer == null) {
      _showError('Please select a retailer first');
      return;
    }

    final amountController = TextEditingController();
    final noteController = TextEditingController();
    DateTime paymentDate = DateTime.now();
    final primary = ref.read(themeProvider).primaryColor;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Record Cash Payment',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Date
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: paymentDate,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setDialogState(() => paymentDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, color: primary, size: 18),
                      const SizedBox(width: 10),
                      Text(DateFormat('dd MMM yyyy').format(paymentDate),
                          style: GoogleFonts.poppins(fontSize: 14)),
                      const Spacer(),
                      Icon(Icons.arrow_drop_down, color: Colors.grey[400]),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Amount
              TextFormField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),

              // Note
              TextFormField(
                controller: noteController,
                decoration: InputDecoration(
                  labelText: 'Note (Optional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.trim());
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter valid amount'), backgroundColor: Colors.red),
                  );
                  return;
                }

                final success = await ref.read(cashPaymentProvider.notifier).addPayment(
                      retailerId: _selectedRetailer!.id,
                      date: DateFormat('yyyy-MM-dd').format(paymentDate),
                      amount: amount,
                      note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                    );

                if (success && ctx.mounted) {
                  Navigator.pop(ctx);
                  await _loadCashPayments();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cash payment recorded!'),
                      backgroundColor: Color(0xFF27AE60),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF27AE60), foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadAndShowBillDetail(BillModel bill) async {
    await ref.read(stockProvider.notifier).fetchHistory(
          retailerId: bill.retailerId,
          fromDate: bill.fromDate,
          toDate: bill.toDate,
        );
    await ref.read(returnProvider.notifier).fetchHistory(
          retailerId: bill.retailerId,
          fromDate: bill.fromDate,
          toDate: bill.toDate,
        );

    // Load cash payments for this bill period
    final cashResult = await ref.read(cashPaymentProvider.notifier).getTotal(
          retailerId: bill.retailerId,
          fromDate: bill.fromDate ?? bill.date,
          toDate: bill.toDate ?? bill.date,
        );

    if (mounted) {
      _showBillDetailDialog(
        bill,
        cashPayments: cashResult['payments'] as List<CashPaymentModel>,
      );
    }
  }

  void _showBillDetailDialog(BillModel bill, {List<CashPaymentModel> cashPayments = const []}) {
    final stockEntries = ref.read(stockProvider).entries;
    final returnEntries = ref.read(returnProvider).returns;
    final primary = ref.read(themeProvider).primaryColor;
    final locale = Localizations.localeOf(context);
    final isTamil = locale.languageCode == 'ta';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 700,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bill Details',
                            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: primary)),
                        Text('Bill #${bill.id}',
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const Divider(),

                // Retailer & Period
                Row(
                  children: [
                    Expanded(child: _infoTile(Icons.store, 'Retailer', bill.retailer?.name ?? '', primary)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _infoTile(
                        Icons.date_range,
                        'Period',
                        '${DateFormat('dd MMM').format(DateTime.parse(bill.fromDate ?? bill.date))} - ${DateFormat('dd MMM yyyy').format(DateTime.parse(bill.toDate ?? bill.date))}',
                        const Color(0xFF8E44AD),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Stock Given
                _sectionTitle(Icons.local_shipping, 'Total Stock Given', const Color(0xFFE67E22)),
                const SizedBox(height: 8),
                stockEntries.isEmpty
                    ? _emptyBox('No stock entries found')
                    : _buildAccumulatedStockTable(stockEntries, const Color(0xFFE67E22), isTamil),
                const SizedBox(height: 16),

                // Returns
                _sectionTitle(Icons.assignment_return, 'Total Stock Returned', const Color(0xFFE74C3C)),
                const SizedBox(height: 8),
                returnEntries.isEmpty
                    ? _emptyBox('No returns recorded')
                    : _buildAccumulatedReturnTable(returnEntries, const Color(0xFFE74C3C), isTamil),
                const SizedBox(height: 16),

                // Bill Items
                _sectionTitle(Icons.receipt_long, 'Bill Calculation', const Color(0xFF8E44AD)),
                const SizedBox(height: 8),
                _buildBillItemsTable(bill, isTamil),
                const SizedBox(height: 16),

                // Cash Payments
                if (cashPayments.isNotEmpty) ...[
                  _sectionTitle(Icons.payments, 'Cash Payments Received', const Color(0xFF27AE60)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF27AE60).withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: cashPayments.asMap().entries.map((e) {
                        final i = e.key;
                        final p = e.value;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: i % 2 == 0 ? Colors.white : const Color(0xFF27AE60).withOpacity(0.03),
                            border: i > 0 ? Border(top: BorderSide(color: Colors.grey[100]!)) : null,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  DateFormat('dd MMM yyyy').format(DateTime.parse(p.date)),
                                  style: GoogleFonts.poppins(fontSize: 13),
                                ),
                              ),
                              if (p.note != null && p.note!.isNotEmpty)
                                Expanded(
                                  child: Text(p.note!, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
                                ),
                              Text(
                                '₹${p.amount.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF27AE60)),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Summary
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: primary.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      _summaryRow('Total Sales', '₹${bill.totalSales.toStringAsFixed(2)}', Colors.black87),
                      const SizedBox(height: 6),
                      _summaryRow(
                          'Commission (${bill.retailer?.commission ?? 0}%)',
                          '- ₹${bill.commission.toStringAsFixed(2)}',
                          Colors.red),
                      const Divider(),
                      _summaryRow('Final Amount', '₹${bill.finalAmount.toStringAsFixed(2)}', const Color(0xFF1E4D78), bold: true),
                      if (bill.paidAmount > 0) ...[
                        const SizedBox(height: 6),
                        _summaryRow('Already Paid', '- ₹${bill.paidAmount.toStringAsFixed(2)}', const Color(0xFF27AE60)),
                        const Divider(),
                        _summaryRow('Balance Due', '₹${bill.balanceAmount.toStringAsFixed(2)}',
                            bill.balanceAmount > 0 ? Colors.red : const Color(0xFF27AE60),
                            bold: true),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await BillPrintService.printBill(
                            context, bill,
                            stockEntry: stockEntries,
                            returnEntry: returnEntries,
                            cashPayments: cashPayments,
                          );
                        },
                        icon: const Icon(Icons.print),
                        label: Text('Print', style: GoogleFonts.poppins()),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primary,
                          side: BorderSide(color: primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Close', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccumulatedStockTable(List stockEntries, Color color, bool isTamil) {
    final Map<int, Map<String, dynamic>> stockMap = {};
    for (final entry in stockEntries) {
      for (final item in entry.items) {
        final pid = item.productId;
        if (stockMap.containsKey(pid)) {
          stockMap[pid]!['qty'] += item.quantity;
        } else {
          stockMap[pid] = {
            'name': isTamil && (item.product?.tamilName ?? '').isNotEmpty
                ? item.product!.tamilName!
                : item.product?.name ?? 'Product',
            'qty': item.quantity,
          };
        }
      }
    }
    return _itemsTable(stockMap.values.map((e) => {'name': e['name'], 'qty': e['qty']}).toList(), color);
  }

  Widget _buildAccumulatedReturnTable(List returnEntries, Color color, bool isTamil) {
    final Map<int, Map<String, dynamic>> returnMap = {};
    for (final entry in returnEntries) {
      for (final item in entry.items) {
        final pid = item.productId;
        if (returnMap.containsKey(pid)) {
          returnMap[pid]!['qty'] += item.quantity;
        } else {
          returnMap[pid] = {
            'name': isTamil && (item.product?.tamilName ?? '').isNotEmpty
                ? item.product!.tamilName!
                : item.product?.name ?? 'Product',
            'qty': item.quantity,
          };
        }
      }
    }
    return _itemsTable(returnMap.values.map((e) => {'name': e['name'], 'qty': e['qty']}).toList(), color);
  }

  Widget _buildBillItemsTable(BillModel bill, bool isTamil) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF1E4D78),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                _billHeader('Product', flex: 3),
                _billHeader('Given'),
                _billHeader('Return'),
                _billHeader('Sold'),
                _billHeader('Price'),
                _billHeader('Amount', flex: 2),
              ],
            ),
          ),
          ...bill.items.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            final productName = isTamil && (item.product?.tamilName ?? '').isNotEmpty
                ? item.product!.tamilName!
                : item.product?.name ?? '';
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: i % 2 == 0 ? Colors.white : const Color(0xFFF8FAFF),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text(productName, style: GoogleFonts.poppins(fontSize: 12))),
                  Expanded(child: Text('${item.givenQty}', style: GoogleFonts.poppins(fontSize: 12))),
                  Expanded(child: Text('${item.returnedQty}', style: GoogleFonts.poppins(fontSize: 12))),
                  Expanded(child: Text('${item.soldQty}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF27AE60)))),
                  Expanded(child: Text('₹${item.price.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 12))),
                  Expanded(flex: 2, child: Text('₹${item.amount.toStringAsFixed(2)}', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600))),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _itemsTable(List<Map<String, dynamic>> items, Color color) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Product', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: color))),
                Text('Qty', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
              ],
            ),
          ),
          ...items.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: i % 2 == 0 ? Colors.white : color.withOpacity(0.03),
                border: Border(top: BorderSide(color: Colors.grey[100]!)),
              ),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text(item['name'], style: GoogleFonts.poppins(fontSize: 13))),
                  Text('${item['qty']}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  Widget _emptyBox(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Center(child: Text(message, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[400]))),
    );
  }

  Widget _infoTile(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
                Text(value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _billHeader(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(text, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11)),
    );
  }

  Widget _summaryRow(String label, String value, Color valueColor, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: valueColor)),
      ],
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> _confirmDeleteBill(BillModel bill) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Bill', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Deleting this bill will allow editing stock and returns.\n\nAre you sure?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final success = await ref.read(billProvider.notifier).deleteBill(bill.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill deleted.'), backgroundColor: Color(0xFF27AE60)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final retailers = ref.watch(retailerProvider).retailers;
    final billState = ref.watch(billProvider);
    final bills = billState.bills;
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.isAdmin ?? false;
    final isUser = user?.isUser ?? false;
    final primary = ref.watch(themeProvider).primaryColor;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= AppConstants.desktopBreakpoint;

    return AppLayout(
      title: 'Bills',
      selectedIndex: 5,
      child: Column(
        children: [
          Container(
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: primary,
              unselectedLabelColor: Colors.grey,
              indicatorColor: primary,
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
              tabs: const [
                Tab(text: 'Generate Bill'),
                Tab(text: 'Cash Payment'),
                Tab(text: 'Bill History'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Generate Bill
                isAdmin || isUser
                    ? SingleChildScrollView(
                        padding: EdgeInsets.all(isDesktop ? 32 : 16),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Generate Bill',
                                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: primary)),
                                  const SizedBox(height: 20),

                                  // Retailer Dropdown
                                  DropdownButtonFormField<UserModel>(
                                    value: _selectedRetailer,
                                    decoration: InputDecoration(
                                      labelText: 'Select Retailer',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                      prefixIcon: const Icon(Icons.store),
                                    ),
                                    items: retailers.map((r) => DropdownMenuItem<UserModel>(value: r, child: Text(r.name))).toList(),
                                    onChanged: (v) {
                                      if (v != null) _onRetailerSelected(v);
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  if (_loadingDates)
                                    const Center(child: CircularProgressIndicator())
                                  else ...[
                                    // From Date
                                    InkWell(
                                      onTap: _selectFromDate,
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
                                        child: Row(
                                          children: [
                                            Icon(Icons.calendar_today, color: primary, size: 20),
                                            const SizedBox(width: 10),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('From Date', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
                                                Text(DateFormat('dd MMM yyyy').format(_fromDate), style: GoogleFonts.poppins(fontSize: 14)),
                                              ],
                                            ),
                                            const Spacer(),
                                            Icon(Icons.arrow_drop_down, color: Colors.grey[400]),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // To Date
                                    InkWell(
                                      onTap: _selectToDate,
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(10)),
                                        child: Row(
                                          children: [
                                            Icon(Icons.calendar_today, color: primary, size: 20),
                                            const SizedBox(width: 10),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text('To Date', style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500])),
                                                Text(DateFormat('dd MMM yyyy').format(_toDate), style: GoogleFonts.poppins(fontSize: 14)),
                                              ],
                                            ),
                                            const Spacer(),
                                            Icon(Icons.arrow_drop_down, color: Colors.grey[400]),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Cash Payments Preview
                                    if (_selectedRetailer != null && _previewPaidAmount > 0)
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF27AE60).withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFF27AE60).withOpacity(0.3)),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text('Cash Already Paid',
                                                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF27AE60))),
                                                Text('₹${_previewPaidAmount.toStringAsFixed(2)}',
                                                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF27AE60))),
                                              ],
                                            ),
                                            ..._previewPayments.map((p) => Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(DateFormat('dd MMM').format(DateTime.parse(p.date)),
                                                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                                                  Text('₹${p.amount.toStringAsFixed(2)}',
                                                      style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                                                ],
                                              ),
                                            )),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(height: 16),
                                  ],

                                  // Generate Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton.icon(
                                      onPressed: billState.isLoading ? null : _generateBill,
                                      icon: billState.isLoading
                                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                          : const Icon(Icons.receipt_long, color: Colors.white),
                                      label: Text(
                                        billState.isLoading ? 'Generating...' : 'Generate Bill',
                                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF8E44AD),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : Center(child: Text('Only admin can generate bills', style: GoogleFonts.poppins(color: Colors.grey[500]))),

                // Tab 2: Cash Payment
                isAdmin || isUser
                    ? _buildCashPaymentTab(isDesktop, primary)
                    : Center(child: Text('Only admin can record payments', style: GoogleFonts.poppins(color: Colors.grey[500]))),

                // Tab 3: Bill History
                billState.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : bills.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text('No bills found', style: GoogleFonts.poppins(color: Colors.grey[500])),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.all(isDesktop ? 24 : 16),
                            itemCount: bills.length,
                            itemBuilder: (ctx, i) {
                              final bill = bills[i];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF8E44AD).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(Icons.receipt_long, color: Color(0xFF8E44AD), size: 24),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(bill.retailer?.name ?? '',
                                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                                              Text(
                                                bill.fromDate != null
                                                    ? '${DateFormat('dd MMM').format(DateTime.parse(bill.fromDate!))} - ${DateFormat('dd MMM yyyy').format(DateTime.parse(bill.toDate ?? bill.date))}'
                                                    : DateFormat('dd MMM yyyy').format(DateTime.parse(bill.date)),
                                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text('₹${bill.balanceAmount > 0 ? bill.balanceAmount.toStringAsFixed(2) : bill.finalAmount.toStringAsFixed(2)}',
                                                style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: bill.balanceAmount > 0 ? Colors.red : const Color(0xFF27AE60))),
                                            Text(
                                              bill.paidAmount > 0 ? 'Paid: ₹${bill.paidAmount.toStringAsFixed(2)}' : 'Sales: ₹${bill.totalSales.toStringAsFixed(2)}',
                                              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () => _loadAndShowBillDetail(bill),
                                          icon: Icon(Icons.visibility, color: primary, size: 18),
                                          label: Text('View', style: GoogleFonts.poppins(color: primary, fontSize: 13)),
                                        ),
                                        if (isAdmin) ...[
                                          const SizedBox(width: 8),
                                          TextButton.icon(
                                            onPressed: () => _confirmDeleteBill(bill),
                                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                                            label: Text('Delete', style: GoogleFonts.poppins(color: Colors.red, fontSize: 13)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashPaymentTab(bool isDesktop, Color primary) {
    final cashState = ref.watch(cashPaymentProvider);

    return Column(
      children: [
        // Add Payment Button
        Padding(
          padding: EdgeInsets.all(isDesktop ? 24 : 16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<UserModel>(
                  value: _selectedRetailer,
                  decoration: InputDecoration(
                    labelText: 'Select Retailer',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: const Icon(Icons.store),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: ref.watch(retailerProvider).retailers
                      .map((r) => DropdownMenuItem<UserModel>(value: r, child: Text(r.name)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _selectedRetailer = v);
                      ref.read(cashPaymentProvider.notifier).fetchPayments(retailerId: v.id);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _showCashPaymentDialog,
                icon: const Icon(Icons.add, color: Colors.white),
                label: Text('Add', style: GoogleFonts.poppins(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27AE60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ],
          ),
        ),

        // Total
        if (cashState.payments.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF27AE60).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF27AE60).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Collected', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  Text('₹${cashState.totalPaid.toStringAsFixed(2)}',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF27AE60))),
                ],
              ),
            ),
          ),

        const SizedBox(height: 12),

        // Payments List
        Expanded(
          child: cashState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : cashState.payments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payments, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('No cash payments found', style: GoogleFonts.poppins(color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16),
                      itemCount: cashState.payments.length,
                      itemBuilder: (ctx, i) {
                        final p = cashState.payments[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF27AE60).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.payments, color: Color(0xFF27AE60), size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(DateFormat('dd MMM yyyy').format(DateTime.parse(p.date)),
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                                    if (p.note != null && p.note!.isNotEmpty)
                                      Text(p.note!, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
                                  ],
                                ),
                              ),
                              Text('₹${p.amount.toStringAsFixed(2)}',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF27AE60))),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                onPressed: () async {
                                  await ref.read(cashPaymentProvider.notifier).deletePayment(p.id);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}