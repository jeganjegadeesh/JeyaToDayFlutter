import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jeyatoday/l10n/app_localizations.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/theme_provider.dart';
import '../../widgets/common/app_layout.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState
    extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Profile controllers
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _profileFormKey = GlobalKey<FormState>();
  bool _profileLoading = false;

  // Password controllers
  final _currentPasswordController =
      TextEditingController();
  final _newPasswordController = TextEditingController();
  final _passwordFormKey = GlobalKey<FormState>();
  bool _passwordLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  void _loadUserData() {
    final user = ref.read(authProvider).user;
    if (user != null) {
      _nameController.text = user.name;
      _mobileController.text = user.mobile;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _mobileController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;
    setState(() => _profileLoading = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.put(
        '/profile',
        data: {
          'name': _nameController.text.trim(),
          'mobile': _mobileController.text.trim(),
        },
      );

      // Update local auth state
      final userData = response.data['user'];
      await ref
          .read(authProvider.notifier)
          .updateLocalUser(userData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!
                  .profileUpdated,
            ),
            backgroundColor: const Color(0xFF27AE60),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  Future<void> _updatePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() => _passwordLoading = true);

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.put(
        '/profile/password',
        data: {
          'current_password':
              _currentPasswordController.text.trim(),
          'new_password':
              _newPasswordController.text.trim(),
        },
      );

      if (mounted) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!
                  .passwordUpdated,
            ),
            backgroundColor: const Color(0xFF27AE60),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted)
        setState(() => _passwordLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final primary =
        ref.watch(themeProvider).primaryColor;
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 1200;

    return AppLayout(
      title: l10n.profile,
      selectedIndex: 7,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isDesktop ? 32 : 16),
        child: Column(
          children: [
            // Profile Header Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primary,
                    primary.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor:
                        Colors.white.withOpacity(0.2),
                    child: Text(
                      (user?.name ?? 'U')[0]
                          .toUpperCase(),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? '',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          user?.mobile ?? '',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white
                                .withOpacity(0.2),
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: Text(
                            user?.role.toUpperCase() ??
                                '',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tabs
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).brightness ==
                        Brightness.dark
                    ? const Color(0xFF1E1E1E)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    labelColor: primary,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: primary,
                    labelStyle: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600),
                    tabs: [
                      Tab(text: l10n.editProfile),
                      Tab(text: l10n.changePassword),
                    ],
                  ),
                  const Divider(height: 1),
                  SizedBox(
                    height: 320,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Edit Profile Tab
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _profileFormKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller:
                                      _nameController,
                                  decoration:
                                      InputDecoration(
                                    labelText: l10n.fullName,
                                    prefixIcon: const Icon(
                                        Icons.person_outline),
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius
                                              .circular(10),
                                    ),
                                  ),
                                  validator: (v) =>
                                      v == null || v.isEmpty
                                          ? 'Name is required'
                                          : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller:
                                      _mobileController,
                                  keyboardType:
                                      TextInputType.phone,
                                  decoration:
                                      InputDecoration(
                                    labelText: l10n.mobile,
                                    prefixIcon: const Icon(
                                        Icons
                                            .phone_android),
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius
                                              .circular(10),
                                    ),
                                  ),
                                  validator: (v) =>
                                      v == null || v.isEmpty
                                          ? 'Mobile is required'
                                          : null,
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed:
                                        _profileLoading
                                            ? null
                                            : _updateProfile,
                                    child: _profileLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child:
                                                CircularProgressIndicator(
                                              color:
                                                  Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(l10n.save),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Change Password Tab
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _passwordFormKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller:
                                      _currentPasswordController,
                                  obscureText: _obscureCurrent,
                                  decoration: InputDecoration(
                                    labelText:
                                        l10n.currentPassword,
                                    prefixIcon: const Icon(
                                        Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscureCurrent
                                          ? Icons.visibility_off
                                          : Icons.visibility),
                                      onPressed: () => setState(
                                          () => _obscureCurrent =
                                              !_obscureCurrent),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius
                                              .circular(10),
                                    ),
                                  ),
                                  validator: (v) =>
                                      v == null || v.isEmpty
                                          ? 'Required'
                                          : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller:
                                      _newPasswordController,
                                  obscureText: _obscureNew,
                                  decoration: InputDecoration(
                                    labelText:
                                        l10n.newPassword,
                                    prefixIcon: const Icon(
                                        Icons.lock_open),
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscureNew
                                          ? Icons.visibility_off
                                          : Icons.visibility),
                                      onPressed: () => setState(
                                          () => _obscureNew =
                                              !_obscureNew),
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius
                                              .circular(10),
                                    ),
                                  ),
                                  validator: (v) {
                                    if (v == null ||
                                        v.isEmpty) {
                                      return 'Required';
                                    }
                                    if (v.length < 6) {
                                      return 'Min 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed:
                                        _passwordLoading
                                            ? null
                                            : _updatePassword,
                                    child: _passwordLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child:
                                                CircularProgressIndicator(
                                              color:
                                                  Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Text(l10n
                                            .changePassword),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}