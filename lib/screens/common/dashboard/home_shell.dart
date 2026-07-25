import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_provider.dart';
import '../../admin/company/company_screen.dart';
import 'admin_manager_shell.dart';
import 'retailer_shell.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user!;

    // First-login gate: a freshly-provisioned admin must complete Company
    // Setup before reaching the dashboard. Once the form is saved,
    // is_setup_complete flips server-side; refreshUser() below pulls that
    // change back down, and this widget rebuilds straight into the
    // regular AdminManagerShell — no manual navigation needed.
    if (user.isAdmin && user.company != null && !user.company!.isSetupComplete) {
      return CompanyScreen(
        onboarding: true,
        onSaved: () => ref.read(authProvider).refreshUser(),
      );
    }

    return user.canManage ? const AdminManagerShell() : const RetailerShell();
  }
}