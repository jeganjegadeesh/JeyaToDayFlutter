import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/product_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/product_provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/common/app_layout.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() =>
      _ProductsScreenState();
}

class _ProductsScreenState
    extends ConsumerState<ProductsScreen> {
  final _searchController = TextEditingController();
  List<ProductModel> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        ref.read(productProvider.notifier).fetchProducts());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(
      String query, List<ProductModel> allProducts) {
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = allProducts;
      } else {
        _filteredProducts = allProducts
            .where((p) =>
                p.name
                    .toLowerCase()
                    .contains(query.toLowerCase()) ||
                (p.category ?? '')
                    .toLowerCase()
                    .contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _showProductDialog(
      {ProductModel? product, required bool isAdmin}) {
    if (!isAdmin) return;

    final l10n = AppLocalizations.of(context)!;
    final nameController =
        TextEditingController(text: product?.name ?? '');
    final priceController = TextEditingController(
        text: product?.price.toString() ?? '');
    final categoryController = TextEditingController(
        text: product?.category ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(
          product == null
              ? l10n.addProduct
              : l10n.editProduct,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600),
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // English Name
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: l10n.productName,
                    hintText: 'e.g. Cup Ice Cream',
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(10)),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty
                          ? 'Name is required'
                          : null,
                ),
                const SizedBox(height: 12),

                // Price
                TextFormField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.price,
                    prefixText: '₹ ',
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(10)),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty
                          ? 'Price is required'
                          : null,
                ),
                const SizedBox(height: 12),

                // Category
                TextFormField(
                  controller: categoryController,
                  decoration: InputDecoration(
                    labelText:
                        '${l10n.category} (Optional)',
                    border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate())
                return;
              if (product == null) {
                await ref
                    .read(productProvider.notifier)
                    .createProduct(
                      name: nameController.text.trim(),
                      price: double.parse(
                          priceController.text.trim()),
                      category:
                          categoryController.text.trim(),
                    );
              } else {
                await ref
                    .read(productProvider.notifier)
                    .updateProduct(
                      id: product.id,
                      name: nameController.text.trim(),
                      price: double.parse(
                          priceController.text.trim()),
                      category:
                          categoryController.text.trim(),
                    );
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(product == null
                ? l10n.add
                : l10n.update),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productProvider);
    final allProducts = state.products;
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.isAdmin ?? false;
    final primary =
        ref.watch(themeProvider).primaryColor;
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final isTamil = locale.languageCode == 'ta';
    final size = MediaQuery.of(context).size;
    final isDesktop =
        size.width >= AppConstants.desktopBreakpoint;

    if (_searchController.text.isEmpty) {
      _filteredProducts = allProducts;
    }

    final products = _searchController.text.isEmpty
        ? allProducts
        : _filteredProducts;

    return AppLayout(
      title: l10n.products,
      selectedIndex: 1,
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _showProductDialog(
                  isAdmin: isAdmin),
              backgroundColor: primary,
              icon: const Icon(Icons.add,
                  color: Colors.white),
              label: Text(l10n.addProduct,
                  style: GoogleFonts.poppins(
                      color: Colors.white)),
            )
          : null,
      child: state.isLoading
          ? const Center(
              child: CircularProgressIndicator())
          : Column(
              children: [
                // Search Bar
                Padding(
                  padding: EdgeInsets.all(
                      isDesktop ? 24 : 16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) =>
                        _onSearch(v, allProducts),
                    decoration: InputDecoration(
                      hintText:
                          '${l10n.search} products...',
                      prefixIcon:
                          const Icon(Icons.search),
                      suffixIcon: _searchController
                              .text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                  Icons.clear),
                              onPressed: () {
                                _searchController
                                    .clear();
                                _onSearch(
                                    '', allProducts);
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),

                // Products List
                Expanded(
                  child: products.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(Icons.icecream,
                                  size: 64,
                                  color:
                                      Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                l10n.noDataFound,
                                style:
                                    GoogleFonts.poppins(
                                        color: Colors
                                            .grey[500]),
                              ),
                            ],
                          ),
                        )
                      : isDesktop
                          ? _buildDesktopTable(products,
                              isAdmin, isTamil, l10n,
                              primary)
                          : _buildMobileList(products,
                              isAdmin, isTamil, primary),
                ),
              ],
            ),
    );
  }

  Widget _buildDesktopTable(
      List<ProductModel> products,
      bool isAdmin,
      bool isTamil,
      AppLocalizations l10n,
      Color primary) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10)
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: primary,
                borderRadius:
                    const BorderRadius.vertical(
                        top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  _tableHeader(l10n.productName,
                      flex: 3),
                  _tableHeader(l10n.category,
                      flex: 2),
                  _tableHeader(l10n.price, flex: 1),
                  if (isAdmin)
                    _tableHeader('Actions', flex: 1),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: products.length,
                itemBuilder: (ctx, i) {
                  final p = products[i];
                  final displayName = p.name;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: i % 2 == 0
                          ? Colors.white
                          : const Color(0xFFF8FAFF),
                      border: Border(
                          bottom: BorderSide(
                              color: Colors.grey[100]!)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(displayName,
                              style: GoogleFonts.poppins(
                                  fontSize: 14)),
                        ),
                        
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4),
                            decoration: BoxDecoration(
                              color: primary
                                  .withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(
                                      20),
                            ),
                            child: Text(
                                p.category ?? 'General',
                                style:
                                    GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: primary)),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text('₹${p.price}',
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight:
                                      FontWeight.w600,
                                  color: const Color(
                                      0xFF27AE60))),
                        ),
                        if (isAdmin)
                          Expanded(
                            flex: 1,
                            child: Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit,
                                      color: primary,
                                      size: 20),
                                  onPressed: () =>
                                      _showProductDialog(
                                          product: p,
                                          isAdmin:
                                              isAdmin),
                                ),
                                IconButton(
                                  icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 20),
                                  onPressed: () =>
                                      _confirmDelete(
                                          p.id, l10n),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileList(
      List<ProductModel> products,
      bool isAdmin,
      bool isTamil,
      Color primary) {
    return ListView.builder(
      padding:
          const EdgeInsets.symmetric(horizontal: 16),
      itemCount: products.length,
      itemBuilder: (ctx, i) {
        final p = products[i];
        final displayName =  p.name;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8)
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: Icon(Icons.icecream,
                    color: primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(displayName,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    if (isTamil && p.name.isNotEmpty)
                      Text(p.name,
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey[500])),
                    Text(p.category ?? 'General',
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[400])),
                  ],
                ),
              ),
              Text('₹${p.price}',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF27AE60))),
              if (isAdmin) ...[
                IconButton(
                  icon: Icon(Icons.edit,
                      color: primary, size: 20),
                  onPressed: () => _showProductDialog(
                      product: p, isAdmin: isAdmin),
                ),
                IconButton(
                  icon: const Icon(Icons.delete,
                      color: Colors.red, size: 20),
                  onPressed: () => _confirmDelete(
                      p.id,
                      AppLocalizations.of(context)!),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _tableHeader(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(text,
          style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13)),
    );
  }

  void _confirmDelete(int id, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteProduct,
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600)),
        content: Text(l10n.deleteConfirm,
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel)),
          ElevatedButton(
            onPressed: () async {
              await ref
                  .read(productProvider.notifier)
                  .deleteProduct(id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}