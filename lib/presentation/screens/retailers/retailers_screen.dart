import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/user_model.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/retailer_provider.dart';
import '../../widgets/common/app_layout.dart';

class RetailersScreen extends ConsumerStatefulWidget {
  const RetailersScreen({super.key});

  @override
  ConsumerState<RetailersScreen> createState() => _RetailersScreenState();
}

class _RetailersScreenState extends ConsumerState<RetailersScreen> {
  final _searchController = TextEditingController();
  List<UserModel> _filteredRetailers = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(retailerProvider.notifier).fetchRetailers());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query, List<UserModel> allRetailers) {
    setState(() {
      if (query.isEmpty) {
        _filteredRetailers = allRetailers;
      } else {
        _filteredRetailers = allRetailers
            .where((r) =>
                r.name.toLowerCase().contains(query.toLowerCase()) ||
                r.mobile.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _showRetailerDialog({UserModel? retailer}) {
    final nameController =
        TextEditingController(text: retailer?.name ?? '');
    final mobileController =
        TextEditingController(text: retailer?.mobile ?? '');
    final passwordController = TextEditingController();
    final commissionController = TextEditingController(
        text: retailer?.commission.toString() ?? '0');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(
          retailer == null ? 'Add Retailer' : 'Edit Retailer',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Mobile Number',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Mobile is required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: retailer == null
                        ? 'Password'
                        : 'New Password (leave blank to keep)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  validator: (v) {
                    if (retailer == null &&
                        (v == null || v.isEmpty)) {
                      return 'Password is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: commissionController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Commission (%)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
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
              if (!formKey.currentState!.validate()) return;

              bool success = false;

              if (retailer == null) {
                success = await ref
                    .read(retailerProvider.notifier)
                    .createRetailer(
                      name: nameController.text.trim(),
                      mobile: mobileController.text.trim(),
                      password: passwordController.text.trim(),
                      commission: double.tryParse(
                              commissionController.text.trim()) ??
                          0,
                    );
              } else {
                success = await ref
                    .read(retailerProvider.notifier)
                    .updateRetailer(
                      id: retailer.id,
                      name: nameController.text.trim(),
                      mobile: mobileController.text.trim(),
                      commission: double.tryParse(
                              commissionController.text.trim()) ??
                          0,
                      password: passwordController.text.isNotEmpty
                          ? passwordController.text.trim()
                          : null,
                    );
              }

              if (ctx.mounted) {
                Navigator.pop(ctx);
                if (success) {
                  // Reset search after add/edit
                  _searchController.clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(retailer == null
                          ? 'Retailer added successfully!'
                          : 'Retailer updated successfully!'),
                      backgroundColor: const Color(0xFF27AE60),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          ref.read(retailerProvider).error ??
                              'Something went wrong'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E75B6),
              foregroundColor: Colors.white,
            ),
            child: Text(retailer == null ? 'Add' : 'Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(retailerProvider);
    final allRetailers = state.retailers;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= AppConstants.desktopBreakpoint;

    // Sync filtered list
    if (_searchController.text.isEmpty) {
      _filteredRetailers = allRetailers;
    }

    final retailers = _searchController.text.isEmpty
        ? allRetailers
        : _filteredRetailers;

    return AppLayout(
      title: 'Retailers',
      selectedIndex: 2,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRetailerDialog(),
        backgroundColor: const Color(0xFF27AE60),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('Add Retailer',
            style: GoogleFonts.poppins(color: Colors.white)),
      ),
      child: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search Bar
                Padding(
                  padding: EdgeInsets.all(isDesktop ? 24 : 16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => _onSearch(v, allRetailers),
                    decoration: InputDecoration(
                      hintText: 'Search retailers...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _onSearch('', allRetailers);
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),

                // Retailers List
                Expanded(
                  child: retailers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(Icons.store,
                                  size: 64,
                                  color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'No retailers match your search'
                                    : 'No retailers found',
                                style: GoogleFonts.poppins(
                                    color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        )
                      : isDesktop
                          ? _buildDesktopTable(retailers)
                          : _buildMobileList(retailers),
                ),
              ],
            ),
    );
  }

  Widget _buildDesktopTable(List<UserModel> retailers) {
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.isAdmin ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
              decoration: const BoxDecoration(
                color: Color(0xFF1E4D78),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  _tableHeader('Name', flex: 3),
                  _tableHeader('Mobile', flex: 2),
                  _tableHeader('Commission', flex: 2),
                  _tableHeader('Actions', flex: 1),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: retailers.length,
                itemBuilder: (ctx, i) {
                  final r = retailers[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: i % 2 == 0
                          ? Colors.white
                          : const Color(0xFFF8FAFF),
                      border: Border(
                          bottom:
                              BorderSide(color: Colors.grey[100]!)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                    const Color(0xFF27AE60)
                                        .withOpacity(0.1),
                                radius: 18,
                                child: Text(
                                  r.name[0].toUpperCase(),
                                  style: GoogleFonts.poppins(
                                      color: const Color(0xFF27AE60),
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(r.name,
                                  style: GoogleFonts.poppins(
                                      fontSize: 14)),
                            ],
                          ),
                        ),
                        Expanded(
                            flex: 2,
                            child: Text(r.mobile,
                                style: GoogleFonts.poppins(
                                    fontSize: 14))),
                        Expanded(
                          flex: 2,
                          child: Text('${r.commission}%',
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFE67E22))),
                        ),
                        Expanded(
                          flex: 1,
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Color(0xFF2E75B6),
                                    size: 20),
                                onPressed: () =>
                                    _showRetailerDialog(retailer: r),
                              ),
                              if(isAdmin)
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.red, size: 20),
                                onPressed: () =>
                                    _confirmDelete(r.id),
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

  Widget _buildMobileList(List<UserModel> retailers) {
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.isAdmin ?? false;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: retailers.length,
      itemBuilder: (ctx, i) {
        final r = retailers[i];
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
              CircleAvatar(
                backgroundColor:
                    const Color(0xFF27AE60).withOpacity(0.1),
                radius: 24,
                child: Text(
                  r.name[0].toUpperCase(),
                  style: GoogleFonts.poppins(
                      color: const Color(0xFF27AE60),
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.name,
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14)),
                    Text(r.mobile,
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[500])),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE67E22).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${r.commission}%',
                    style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFFE67E22),
                        fontWeight: FontWeight.w600)),
              ),
              IconButton(
                icon: const Icon(Icons.edit,
                    color: Color(0xFF2E75B6), size: 20),
                onPressed: () => _showRetailerDialog(retailer: r),
              ),
              if (isAdmin)
              IconButton(
                icon: const Icon(Icons.delete,
                    color: Colors.red, size: 20),
                onPressed: () => _confirmDelete(r.id),
              ),
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

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Retailer',
            style:
                GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
            'Are you sure you want to delete this retailer?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref
                  .read(retailerProvider.notifier)
                  .deleteRetailer(id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}