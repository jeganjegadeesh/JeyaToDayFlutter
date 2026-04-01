import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/providers/product_provider.dart';
import '../../../data/providers/retailer_provider.dart';
import '../../../data/providers/stock_provider.dart';
import '../../widgets/common/app_layout.dart';

class StockScreen extends ConsumerStatefulWidget {
  const StockScreen({super.key});

  @override
  ConsumerState<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends ConsumerState<StockScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  UserModel? _selectedRetailer;
  DateTime _selectedDate = DateTime.now();
  final List<Map<String, dynamic>> _stockItems = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() {
      ref.read(productProvider.notifier).fetchProducts();
      ref.read(retailerProvider.notifier).fetchRetailers();
      ref.read(stockProvider.notifier).fetchHistory();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _addStockItem() {
    final products = ref.read(productProvider).products;
    if (products.isEmpty) return;
    setState(() {
      _stockItems.add({
        'product': products.first,
        'quantity': '',
        'controller': TextEditingController(),
      });
    });
  }

  void _removeStockItem(int index) {
    (_stockItems[index]['controller'] as TextEditingController)
        .dispose();
    setState(() => _stockItems.removeAt(index));
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _submitStock() async {
    if (_selectedRetailer == null) {
      _showError('Please select a retailer');
      return;
    }
    if (_stockItems.isEmpty) {
      _showError('Please add at least one product');
      return;
    }

    // Validate quantities
    for (int i = 0; i < _stockItems.length; i++) {
      final qty = int.tryParse(
          (_stockItems[i]['controller'] as TextEditingController)
              .text
              .trim());
      if (qty == null || qty <= 0) {
        _showError('Please enter valid quantity for all products');
        return;
      }
    }

    final items = _stockItems
        .map((item) => StockItem(
              productId: (item['product'] as ProductModel).id,
              productName: (item['product'] as ProductModel).name,
              quantity: int.parse(
                  (item['controller'] as TextEditingController)
                      .text
                      .trim()),
            ))
        .toList();

    final success = await ref.read(stockProvider.notifier).giveStock(
          retailerId: _selectedRetailer!.id,
          date: DateFormat('yyyy-MM-dd').format(_selectedDate),
          items: items,
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock distributed successfully!'),
          backgroundColor: Color(0xFF27AE60),
        ),
      );
      // Clear form
      for (final item in _stockItems) {
        (item['controller'] as TextEditingController).dispose();
      }
      setState(() {
        _selectedRetailer = null;
        _stockItems.clear();
      });
      // Refresh history
      ref.read(stockProvider.notifier).fetchHistory();
      // Switch to history tab
      _tabController.animateTo(1);
    } else if (mounted) {
      _showError(
          ref.read(stockProvider).error ?? 'Something went wrong');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _showEditDialog(dynamic entry) {
    final retailers = ref.read(retailerProvider).retailers;
    final products = ref.read(productProvider).products;

    UserModel? selectedRetailer;
    try {
      selectedRetailer = retailers
          .firstWhere((r) => r.id == entry.retailerId);
    } catch (_) {}

    DateTime selectedDate = DateTime.parse(entry.date.toString());
    final List<Map<String, dynamic>> editItems = entry.items
        .map<Map<String, dynamic>>((item) => {
              'product': products.firstWhere(
                (p) => p.id == item.productId,
                orElse: () => products.first,
              ),
              'controller': TextEditingController(
                  text: item.quantity.toString()),
            })
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Edit Stock Entry',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Date
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2024),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setDialogState(
                            () => selectedDate = picked);
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
                          const Icon(Icons.calendar_today,
                              color: Color(0xFF2E75B6), size: 20),
                          const SizedBox(width: 10),
                          Text(
                            DateFormat('dd MMM yyyy')
                                .format(selectedDate),
                            style: GoogleFonts.poppins(fontSize: 14),
                          ),
                          const Spacer(),
                          Icon(Icons.arrow_drop_down,
                              color: Colors.grey[400]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Retailer
                  DropdownButtonFormField<UserModel>(
                    value: selectedRetailer,
                    decoration: InputDecoration(
                      labelText: 'Retailer',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.store),
                    ),
                    items: retailers
                        .map((r) => DropdownMenuItem<UserModel>(
                              value: r,
                              child: Text(r.name),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedRetailer = v),
                  ),
                  const SizedBox(height: 12),

                  // Items
                  ...editItems.asMap().entries.map((e) {
                    final i = e.key;
                    final item = e.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButton<ProductModel>(
                              value: item['product'] as ProductModel,
                              isExpanded: true,
                              underline: const SizedBox(),
                              items: products
                                  .map((p) =>
                                      DropdownMenuItem<ProductModel>(
                                        value: p,
                                        child: Text(p.name,
                                            style: GoogleFonts.poppins(
                                                fontSize: 13)),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                setDialogState(
                                    () => editItems[i]['product'] = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: item['controller']
                                  as TextEditingController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              decoration: InputDecoration(
                                labelText: 'Qty',
                                border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(8)),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 10),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete,
                                color: Colors.red, size: 20),
                            onPressed: () {
                              setDialogState(
                                  () => editItems.removeAt(i));
                            },
                          ),
                        ],
                      ),
                    );
                  }),

                  // Add Product Button
                  TextButton.icon(
                    onPressed: () {
                      setDialogState(() {
                        editItems.add({
                          'product': products.first,
                          'controller': TextEditingController(),
                        });
                      });
                    },
                    icon: const Icon(Icons.add,
                        color: Color(0xFF2E75B6)),
                    label: Text('Add Product',
                        style: GoogleFonts.poppins(
                            color: const Color(0xFF2E75B6))),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedRetailer == null) return;

                final items = editItems
                    .where((item) =>
                        (item['controller'] as TextEditingController)
                            .text
                            .isNotEmpty)
                    .map((item) => StockItem(
                          productId:
                              (item['product'] as ProductModel).id,
                          productName:
                              (item['product'] as ProductModel).name,
                          quantity: int.tryParse(
                                  (item['controller']
                                          as TextEditingController)
                                      .text) ??
                              0,
                        ))
                    .toList();

                final success = await ref
                    .read(stockProvider.notifier)
                    .giveStock(
                      retailerId: selectedRetailer!.id,
                      date: DateFormat('yyyy-MM-dd')
                          .format(selectedDate),
                      items: items,
                    );

                if (success && ctx.mounted) {
                  Navigator.pop(ctx);
                  ref.read(stockProvider.notifier).fetchHistory();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Stock updated successfully!'),
                      backgroundColor: Color(0xFF27AE60),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE67E22),
                foregroundColor: Colors.white,
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final retailers = ref.watch(retailerProvider).retailers;
    final products = ref.watch(productProvider).products;
    final stockState = ref.watch(stockProvider);
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= AppConstants.desktopBreakpoint;

    return AppLayout(
      title: 'Give Stock',
      selectedIndex: 3,
      child: Column(
        children: [
          // Tab Bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFFE67E22),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFFE67E22),
              labelStyle:
                  GoogleFonts.poppins(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Give Stock'),
                Tab(text: 'Stock History'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Give Stock Tab
                SingleChildScrollView(
                  padding: EdgeInsets.all(isDesktop ? 32 : 16),
                  child: isDesktop
                      ? Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: _buildForm(
                                    retailers,
                                    stockState.isLoading)),
                            const SizedBox(width: 24),
                            Expanded(
                                child: _buildStockItems(products)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildForm(
                                retailers, stockState.isLoading),
                            const SizedBox(height: 16),
                            _buildStockItems(products),
                          ],
                        ),
                ),

                // Stock History Tab
                stockState.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : stockState.entries.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(Icons.local_shipping,
                                    size: 64,
                                    color: Colors.grey[300]),
                                const SizedBox(height: 16),
                                Text('No stock entries found',
                                    style: GoogleFonts.poppins(
                                        color: Colors.grey[500])),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.all(
                                isDesktop ? 24 : 16),
                            itemCount: stockState.entries.length,
                            itemBuilder: (ctx, i) {
                              final entry = stockState.entries[i];
                              return Container(
                                margin: const EdgeInsets.only(
                                    bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black
                                          .withOpacity(0.05),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding:
                                              const EdgeInsets.all(
                                                  10),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                                    0xFFE67E22)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(
                                                    10),
                                          ),
                                          child: const Icon(
                                            Icons.local_shipping,
                                            color: Color(0xFFE67E22),
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment
                                                    .start,
                                            children: [
                                              Text(
                                                entry.retailer
                                                        ?.name ??
                                                    'Retailer #${entry.retailerId}',
                                                style: GoogleFonts
                                                    .poppins(
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              Text(
                                                DateFormat(
                                                        'dd MMM yyyy')
                                                    .format(DateTime
                                                        .parse(entry
                                                            .date
                                                            .toString())),
                                                style: GoogleFonts
                                                    .poppins(
                                                  fontSize: 12,
                                                  color:
                                                      Colors.grey[500],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.edit,
                                              color:
                                                  Color(0xFF2E75B6)),
                                          onPressed: () =>
                                              _showEditDialog(entry),
                                          tooltip: 'Edit',
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    // Items
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: entry.items
                                          .map((item) => Container(
                                                padding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 10,
                                                        vertical: 4),
                                                decoration:
                                                    BoxDecoration(
                                                  color: const Color(
                                                          0xFFE67E22)
                                                      .withOpacity(
                                                          0.08),
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(20),
                                                ),
                                                child: Text(
                                                  '${item.product?.name ?? 'Product'}: ${item.quantity}',
                                                  style: GoogleFonts
                                                      .poppins(
                                                    fontSize: 12,
                                                    color: const Color(
                                                        0xFFE67E22),
                                                    fontWeight:
                                                        FontWeight.w500,
                                                  ),
                                                ),
                                              ))
                                          .toList(),
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

  Widget _buildForm(List<UserModel> retailers, bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Stock Distribution',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E4D78),
            ),
          ),
          const SizedBox(height: 20),

          // Date Picker
          InkWell(
            onTap: _selectDate,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: Color(0xFF2E75B6), size: 20),
                  const SizedBox(width: 10),
                  Text(
                    DateFormat('dd MMM yyyy').format(_selectedDate),
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_drop_down,
                      color: Colors.grey[400]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Retailer Dropdown
          DropdownButtonFormField<UserModel>(
            value: _selectedRetailer,
            decoration: InputDecoration(
              labelText: 'Select Retailer',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              prefixIcon: const Icon(Icons.store),
            ),
            items: retailers
                .map((r) => DropdownMenuItem<UserModel>(
                      value: r,
                      child: Text(r.name),
                    ))
                .toList(),
            onChanged: (v) =>
                setState(() => _selectedRetailer = v),
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : _submitStock,
              icon: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.local_shipping,
                      color: Colors.white),
              label: Text(
                isLoading ? 'Distributing...' : 'Distribute Stock',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE67E22),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockItems(List<ProductModel> products) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Products',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E4D78),
                ),
              ),
              ElevatedButton.icon(
                onPressed: products.isEmpty ? null : _addStockItem,
                icon: const Icon(Icons.add,
                    size: 18, color: Colors.white),
                label: Text('Add',
                    style: GoogleFonts.poppins(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E75B6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_stockItems.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No products added yet.\nTap Add to add products.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      color: Colors.grey[400], fontSize: 14),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _stockItems.length,
              itemBuilder: (ctx, i) {
                final item = _stockItems[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    children: [
                      // Product Dropdown
                      Expanded(
                        flex: 3,
                        child: DropdownButton<ProductModel>(
                          value: item['product'] as ProductModel,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: products
                              .map((p) =>
                                  DropdownMenuItem<ProductModel>(
                                    value: p,
                                    child: Text(p.name,
                                        style: GoogleFonts.poppins(
                                            fontSize: 13)),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            setState(
                                () => _stockItems[i]['product'] = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Quantity Input
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: item['controller']
                              as TextEditingController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: InputDecoration(
                            labelText: 'Qty',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),

                      // Delete
                      IconButton(
                        icon: const Icon(Icons.delete,
                            color: Colors.red),
                        onPressed: () => _removeStockItem(i),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}