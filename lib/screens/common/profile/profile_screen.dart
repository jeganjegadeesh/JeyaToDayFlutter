import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../config/api_config.dart';
import '../../../providers/auth_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/auth_service.dart';
import '../../../services/api_service.dart';
import '../../../widgets/dialogs.dart';

const _kAccentBlue = Color(0xFF3B82F6);
const _kGreen = Color(0xFF10B981);

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  bool _saving = false;
  XFile? _pickedPhoto;

  @override
  void initState() {
    super.initState();
    final u = ref.read(authProvider).user!;
    _nameCtrl = TextEditingController(text: u.name);
    _phoneCtrl = TextEditingController(text: u.phoneNumber);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final t = context.l10n;
    final picker = ImagePicker();
    final result = await showModalBottomSheet<XFile?>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: _kAccentBlue),
              title: Text(t.t('camera')),
              onTap: () async {
                final f = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                if (ctx.mounted) Navigator.pop(ctx, f);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: _kAccentBlue),
              title: Text(t.t('gallery')),
              onTap: () async {
                final f = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                if (ctx.mounted) Navigator.pop(ctx, f);
              },
            ),
          ],
        ),
      ),
    );
    if (result != null) setState(() => _pickedPhoto = result);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final user = await AuthService.updateProfile(
        {
          'name': _nameCtrl.text.trim(),
          'phone_number': _phoneCtrl.text.trim(),
        },
        imagePath: _pickedPhoto?.path,
      );
      if (mounted) {
        ref.read(authProvider).updateUser(user);
        setState(() => _pickedPhoto = null);
        showSnack(context, 'Profile updated.');
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Simple heuristic used only to drive the strength bar's fill/label —
  /// not a validation rule (the server is the source of truth for what's
  /// an acceptable password).
  ({int segments, Color color, String labelKey}) _passwordStrength(String pw) {
    if (pw.isEmpty) return (segments: 0, color: Colors.grey.shade300, labelKey: 'weak');
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(pw);
    final hasDigit = RegExp(r'[0-9]').hasMatch(pw);
    final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(pw);
    final variety = [hasLetter, hasDigit, hasSymbol].where((b) => b).length;
    if (pw.length < 6) return (segments: 1, color: Colors.redAccent, labelKey: 'weak');
    if (pw.length < 10 || variety < 2) return (segments: 2, color: Colors.amber.shade700, labelKey: 'medium');
    return (segments: 3, color: _kGreen, labelKey: 'strong');
  }

  void _openChangePassword() {
    final t = context.l10n;
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool submitting = false;

    InputDecoration fieldDecoration(String label, bool obscured, VoidCallback toggle) {
      return InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.grey.withValues(alpha: 0.08),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        suffixIcon: IconButton(
          icon: Icon(obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
          onPressed: toggle,
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final strength = _passwordStrength(newCtrl.text);
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.t('changePassword'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(t.t('changePasswordHint'), style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: currentCtrl,
                      obscureText: obscureCurrent,
                      decoration: fieldDecoration(
                        t.t('currentPassword'),
                        obscureCurrent,
                        () => setDialogState(() => obscureCurrent = !obscureCurrent),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? t.t('required') : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: newCtrl,
                      obscureText: obscureNew,
                      onChanged: (_) => setDialogState(() {}),
                      decoration: fieldDecoration(
                        t.t('newPassword'),
                        obscureNew,
                        () => setDialogState(() => obscureNew = !obscureNew),
                      ),
                      validator: (v) => (v == null || v.length < 4) ? 'Min 4 characters' : null,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (var i = 0; i < 3; i++)
                          Expanded(
                            child: Container(
                              height: 4,
                              margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                              decoration: BoxDecoration(
                                color: i < strength.segments ? strength.color : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (newCtrl.text.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${t.t('passwordStrength')}: ${t.t(strength.labelKey)}',
                        style: TextStyle(fontSize: 11, color: strength.color),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: submitting ? null : () => Navigator.pop(ctx),
                          child: Text(t.t('cancel')),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: submitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setDialogState(() => submitting = true);
                                  try {
                                    await AuthService.changePassword(currentCtrl.text, newCtrl.text);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (mounted) {
                                      // The old session token is no longer
                                      // meaningful once the password has
                                      // changed — sign out so the person
                                      // has to log back in with the new one.
                                      showSnack(context, t.t('passwordChangedRelogin'));
                                      await ref.read(authProvider).logout();
                                    }
                                  } on ApiException catch (e) {
                                    setDialogState(() => submitting = false);
                                    if (ctx.mounted) showSnack(ctx, e.message, isError: true);
                                  }
                                },
                          icon: submitting
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.check, size: 18),
                          label: Text(t.t('update')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authProvider).user;
    // Logout sets the auth user to null, and because this screen also
    // watches authProvider it can get one more rebuild here in the same
    // frame, just before the root router swaps the whole shell out for
    // the login screen. Render an empty shell for that instant rather
    // than crashing on a null check.
    if (authUser == null) {
      return const SizedBox.shrink();
    }
    final user = authUser;
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    final verifiedLabel = user.isAdmin
        ? t.t('verifiedAdmin')
        : user.isManager
            ? t.t('verifiedManager')
            : t.t('verifiedRetailer');
    final accessLabel = user.isAdmin
        ? t.t('fullAccess')
        : user.isManager
            ? t.t('managerAccess')
            : t.t('standardAccess');
    final memberSince = user.createdAt != null ? DateFormat('MMM yyyy').format(user.createdAt!) : '—';

    ImageProvider? avatarImage;
    if (_pickedPhoto != null) {
      avatarImage = FileImage(File(_pickedPhoto!.path));
    } else if (user.profileImage != null) {
      avatarImage = NetworkImage('${ApiConfig.imageBaseUrl}/${user.profileImage!}');
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: scheme.primaryContainer,
                    backgroundImage: avatarImage,
                    child: avatarImage == null
                        ? Text(
                            user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: scheme.primary),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickPhoto,
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: _kAccentBlue,
                        child: const Icon(Icons.edit, size: 15, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: TextButton.icon(
                onPressed: _pickPhoto,
                icon: const Icon(Icons.image_outlined, size: 18),
                label: Text(t.t('changeProfilePhoto')),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: t.t('name'),
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: t.t('phoneNumber'),
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.t('accountType'), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text(user.type.toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: _kGreen.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, size: 14, color: _kGreen),
                      const SizedBox(width: 4),
                      Text(verifiedLabel, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _kGreen)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(t.t('saveChanges')),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _openChangePassword,
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              icon: const Icon(Icons.lock_outline),
              label: Text(t.t('changePassword')),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => ref.read(authProvider).logout(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Colors.redAccent),
              ),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: Text(t.t('logout'), style: const TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _infoCard(scheme, Icons.calendar_today_outlined, t.t('memberSince'), memberSince)),
                const SizedBox(width: 12),
                Expanded(child: _infoCard(scheme, Icons.verified_user_outlined, t.t('accessLevel'), accessLabel)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(ColorScheme scheme, IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}