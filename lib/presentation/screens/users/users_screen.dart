import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/user_model.dart';
import '../../../data/providers/user_provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../widgets/common/app_layout.dart';

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  final _searchController = TextEditingController();
  List<UserModel> _filteredUsers = [];
  String _selectedRole = 'all';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(userProvider.notifier).fetchUsers());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query, List<UserModel> allUsers) {
    setState(() {
      _filteredUsers = allUsers.where((u) =>
        u.name.toLowerCase().contains(query.toLowerCase()) ||
        u.mobile.toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
  }

  void _showUserDialog({UserModel? user}) {
    final nameController = TextEditingController(text: user?.name ?? '');
    final mobileController = TextEditingController(text: user?.mobile ?? '');
    final passwordController = TextEditingController();
    final commissionController = TextEditingController(text: user?.commission.toString() ?? '0');
    String selectedRole = user?.role ?? 'retailer';
    final formKey = GlobalKey<FormState>();
    final primary = ref.read(themeProvider).primaryColor;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            user == null ? 'Add User' : 'Edit User',
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: mobileController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Mobile Number',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: user == null ? 'Password' : 'New Password (leave blank)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) {
                      if (user == null && (v == null || v.isEmpty)) return 'Required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // Role Dropdown
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    decoration: InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: ['user', 'retailer'].map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(r.toUpperCase()),
                    )).toList(),
                    onChanged: (v) => setDialogState(() => selectedRole = v!),
                  ),
                  const SizedBox(height: 12),
                  if (selectedRole == 'retailer')
                    TextFormField(
                      controller: commissionController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Commission (%)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                bool success;
                if (user == null) {
                  success = await ref.read(userProvider.notifier).createUser(
                    name: nameController.text.trim(),
                    mobile: mobileController.text.trim(),
                    password: passwordController.text.trim(),
                    role: selectedRole,
                    commission: double.tryParse(commissionController.text.trim()) ?? 0,
                  );
                } else {
                  success = await ref.read(userProvider.notifier).updateUser(
                    id: user.id,
                    name: nameController.text.trim(),
                    mobile: mobileController.text.trim(),
                    role: selectedRole,
                    commission: double.tryParse(commissionController.text.trim()) ?? 0,
                    password: passwordController.text.isNotEmpty ? passwordController.text.trim() : null,
                  );
                }
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(success ? 'User ${user == null ? 'created' : 'updated'} successfully!' : ref.read(userProvider).error ?? 'Error'),
                    backgroundColor: success ? const Color(0xFF27AE60) : Colors.red,
                  ));
                }
              },
              child: Text(user == null ? 'Add' : 'Update'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userProvider);
    final allUsers = state.users;
    final primary = ref.watch(themeProvider).primaryColor;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= AppConstants.desktopBreakpoint;

    // Filter by role
    List<UserModel> roleFiltered = _selectedRole == 'all'
        ? allUsers
        : allUsers.where((u) => u.role == _selectedRole).toList();

    final users = _searchController.text.isEmpty ? roleFiltered : _filteredUsers;

    return AppLayout(
      title: 'User Management',
      selectedIndex: 9,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUserDialog(),
        backgroundColor: primary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: Text('Add User', style: GoogleFonts.poppins(color: Colors.white)),
      ),
      child: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search & Filter Bar
                Padding(
                  padding: EdgeInsets.all(isDesktop ? 24 : 16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: (v) => _onSearch(v, roleFiltered),
                        decoration: InputDecoration(
                          hintText: 'Search users...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearch('', roleFiltered);
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Role Filter Chips
                      Row(
                        children: ['all', 'admin', 'user', 'retailer'].map((role) {
                          final isSelected = _selectedRole == role;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(role.toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: isSelected ? Colors.white : primary,
                                    fontWeight: FontWeight.w600,
                                  )),
                              selected: isSelected,
                              selectedColor: primary,
                              backgroundColor: primary.withOpacity(0.1),
                              checkmarkColor: Colors.white,
                              onSelected: (v) => setState(() => _selectedRole = role),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),

                // Users List
                Expanded(
                  child: users.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text('No users found', style: GoogleFonts.poppins(color: Colors.grey[500])),
                            ],
                          ),
                        )
                      : isDesktop
                          ? _buildDesktopTable(users, primary)
                          : _buildMobileList(users, primary),
                ),
              ],
            ),
    );
  }

  Widget _buildDesktopTable(List<UserModel> users, Color primary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E1E1E)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  _th('Name', flex: 3),
                  _th('Mobile', flex: 2),
                  _th('Role', flex: 2),
                  _th('Commission', flex: 2),
                  _th('Actions', flex: 1),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: users.length,
                itemBuilder: (ctx, i) {
                  final u = users[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: i % 2 == 0 ? Colors.white : const Color(0xFFF8FAFF),
                      border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: (u.isAdmin
                                    ? const Color(0xFF2E75B6)
                                    : const Color(0xFF27AE60)).withOpacity(0.1),
                                radius: 18,
                                child: Text(
                                  u.name[0].toUpperCase(),
                                  style: GoogleFonts.poppins(
                                    color: u.isAdmin ? const Color(0xFF2E75B6) : const Color(0xFF27AE60),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(u.name, style: GoogleFonts.poppins(fontSize: 14)),
                            ],
                          ),
                        ),
                        Expanded(flex: 2, child: Text(u.mobile, style: GoogleFonts.poppins(fontSize: 14))),
                        Expanded(
                          flex: 2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (u.isAdmin ? const Color(0xFF2E75B6) : const Color(0xFF27AE60)).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              u.role.toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: u.isAdmin ? const Color(0xFF2E75B6) : const Color(0xFF27AE60),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            u.isRetailer ? '${u.commission}%' : '-',
                            style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFFE67E22)),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit, color: ref.read(themeProvider).primaryColor, size: 20),
                                onPressed: () => _showUserDialog(user: u),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                onPressed: () => _confirmDelete(u.id, u.name),
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

  Widget _buildMobileList(List<UserModel> users, Color primary) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: users.length,
      itemBuilder: (ctx, i) {
        final u = users[i];
        final roleColor = (u.isAdmin || u.isUser) ? const Color(0xFF2E75B6) : const Color(0xFF27AE60);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E1E1E)
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: roleColor.withOpacity(0.1),
                radius: 24,
                child: Text(
                  u.name[0].toUpperCase(),
                  style: GoogleFonts.poppins(color: roleColor, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(u.mobile, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: roleColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  u.role.toUpperCase(),
                  style: GoogleFonts.poppins(fontSize: 10, color: roleColor, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: Icon(Icons.edit, color: primary, size: 20),
                onPressed: () => _showUserDialog(user: u),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: () => _confirmDelete(u.id, u.name),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _th(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(text, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  void _confirmDelete(int id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete User', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Are you sure you want to delete $name?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await ref.read(userProvider.notifier).deleteUser(id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}