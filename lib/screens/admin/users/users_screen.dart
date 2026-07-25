import 'dart:io';
import 'package:aj_project/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/network_url.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/app_user.dart';
import '../../../services/crud_service.dart';
import '../../../services/api_service.dart';
import '../../../widgets/dialogs.dart';

// Brand accent used for the FAB / selected chip / links - looks fine on both
// light and dark surfaces so it stays constant. Everything else below reads
// from Theme.of(context).colorScheme so the screen adapts automatically.
const _kAccentBlue = Color(0xFF3B82F6);

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _service = CrudService<AppUser>(NetworkUrl.users, AppUser.fromJson);
  List<AppUser> _items = [];
  bool _loading = true;
  String _search = '';
  String? _typeFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _service.list(query: {
        if (_search.isNotEmpty) 'search': _search,
        if (_typeFilter != null) 'type': _typeFilter,
      });
      setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitUser({
    required Map<String, String> fields,
    required int? existingId,
    XFile? photo,
  }) async {
    if (photo == null) {
      if (existingId == null) {
        await _service.create(fields);
      } else {
        await _service.update(existingId, fields);
      }
      return;
    }

    if (existingId == null) {
      await _service.createWithFile(fields, fileField: 'profile_image', filePath: photo.path);
    } else {
      await _service.updateWithFile(existingId, fields, fileField: 'profile_image', filePath: photo.path);
    }
  }

  Future<XFile?> _pickImage(BuildContext context) async {
    final picker = ImagePicker();
    return showModalBottomSheet<XFile?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: _kAccentBlue),
              title: const Text('Camera'),
              onTap: () async {
                final f = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                if (ctx.mounted) Navigator.pop(ctx, f);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: _kAccentBlue),
              title: const Text('Gallery'),
              onTap: () async {
                final f = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
                if (ctx.mounted) Navigator.pop(ctx, f);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openForm(BuildContext context, {AppUser? existing}) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phoneNumber ?? '');
    String type = existing?.type ?? 'manager';
    XFile? pickedImage;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            existing == null ? t.t('addUser') : t.t('editUser'),
            style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: scheme.primaryContainer,
                          backgroundImage: pickedImage != null
                              ? FileImage(File(pickedImage!.path))
                              : (existing?.profileImage != null
                                  ? NetworkImage('${ApiConfig.imageBaseUrl}/${existing!.profileImage!}')
                                  : null) as ImageProvider?,
                          child: (pickedImage == null && existing?.profileImage == null)
                              ? Icon(Icons.person, size: 40, color: scheme.primary)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () async {
                              final f = await _pickImage(ctx);
                              if (f != null) setDialogState(() => pickedImage = f);
                            },
                            child: const CircleAvatar(
                              radius: 14,
                              backgroundColor: _kAccentBlue,
                              child: Icon(Icons.edit, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: _fieldDecoration(context, t.t('name'), Icons.badge_outlined),
                    validator: (v) => (v == null || v.isEmpty) ? t.t('required') : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: _fieldDecoration(context, t.t('type'), Icons.workspace_premium_outlined),
                    items: [
                      DropdownMenuItem(value: 'manager', child: Text(t.t('manager'))),
                      DropdownMenuItem(value: 'admin', child: Text(t.t('admin'))),
                    ],
                    onChanged: (v) => setDialogState(() => type = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: _fieldDecoration(context, t.t('phoneNumber'), Icons.phone_outlined),
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v == null || v.isEmpty) ? t.t('required') : null,
                  ),
                  if (existing == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        t.t('defaultPasswordHint'),
                        style: TextStyle(fontSize: 12, color: scheme.outline),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t.t('cancel'), style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _kAccentBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final body = {
                  'name': nameCtrl.text.trim(),
                  'type': type,
                  'phone_number': phoneCtrl.text.trim(),
                };
                try {
                  await _submitUser(
                    fields: body,
                    existingId: existing?.id,
                    photo: pickedImage,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } on ApiException catch (e) {
                  showSnack(ctx, e.message, isError: true);
                }
              },
              child: Text(t.t('save')),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(BuildContext context, String label, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: scheme.onSurfaceVariant),
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Future<void> _delete(AppUser u) async {
    final t = context.l10n;
    final ok = await confirmDialog(
      context,
      title: t.t('deleteUser'),
      message: '${t.t('deleteUserConfirm')} "${u.name}"',
    );
    if (!ok) return;
    try {
      await _service.delete(u.id);
      _load();
    } on ApiException catch (e) {
      showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _resetPassword(AppUser u) async {
    final t = context.l10n;
    final ok = await confirmDialog(
      context,
      title: t.t('resetPassword'),
      message: '"${u.name}" — ${t.t('resetPasswordConfirm')}',
    );
    if (!ok) return;
    try {
      await ApiService.post(NetworkUrl.userResetPassword(u.id));
      if (mounted) showSnack(context, t.t('passwordResetSuccess'));
    } on ApiException catch (e) {
      showSnack(context, e.message, isError: true);
    }
  }

  // ---- Style helpers - all theme aware so light & dark both work ----

  Color _badgeBg(BuildContext context, String type) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = type == 'admin' ? const Color(0xFFE0507A) : _kAccentBlue;
    return base.withValues(alpha: isDark ? 0.22 : 0.12);
  }

  Color _badgeText(BuildContext context, String type) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = type == 'admin' ? const Color(0xFFE0507A) : _kAccentBlue;
    // Lighten slightly in dark mode so the text stays readable on a dark card.
    return isDark ? Color.lerp(base, Colors.white, 0.25)! : base;
  }

  List<Color> _avatarPalette(BuildContext context, int seed) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const hues = [
      Color(0xFF6366F1),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFDB2777),
    ];
    final hue = hues[seed % hues.length];
    return [hue.withValues(alpha: isDark ? 0.28 : 0.15), hue];
  }

  String _maskPhone(String phone) {
    if (phone.length <= 5) return phone;
    return '${phone.substring(0, 5)}****';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: _kAccentBlue,
        shape: const CircleBorder(),
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: t.t('searchByName'),
                hintStyle: TextStyle(color: scheme.outline),
                prefixIcon: Icon(Icons.search, color: scheme.outline),
                filled: true,
                fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
              ),
              onSubmitted: (v) {
                _search = v;
                _load();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip(context, label: t.t('all'), value: null),
                  const SizedBox(width: 10),
                  _filterChip(context, label: t.t('admin'), value: 'admin'),
                  const SizedBox(width: 10),
                  _filterChip(context, label: t.t('manager'), value: 'manager'),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kAccentBlue))
                : _items.isEmpty
                    ? Center(
                        child: Text(
                          t.t('noUsersFound'),
                          style: TextStyle(color: scheme.outline),
                        ),
                      )
                    : RefreshIndicator(
                        color: _kAccentBlue,
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                          itemCount: _items.length,
                          itemBuilder: (_, i) {
                            final u = _items[i];
                            final palette = _avatarPalette(context, i);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: scheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: scheme.shadow.withValues(alpha: 0.06),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: palette[0],
                                    backgroundImage: u.profileImage != null
                                        ? NetworkImage('${ApiConfig.imageBaseUrl}/${u.profileImage!}')
                                        : null,
                                    child: u.profileImage == null
                                        ? Text(
                                            u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                                            style: TextStyle(
                                              color: palette[1],
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                u.name,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                  color: scheme.onSurface,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: _badgeBg(context, u.type),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                u.type == 'admin' ? t.t('admin') : t.t('manager'),
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: _badgeText(context, u.type),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(Icons.phone, size: 13, color: scheme.outline),
                                            const SizedBox(width: 4),
                                            Text(
                                              _maskPhone(u.phoneNumber),
                                              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert, color: scheme.outline),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    onSelected: (v) {
                                      if (v == 'edit') _openForm(context, existing: u);
                                      if (v == 'reset') _resetPassword(u);
                                      if (v == 'delete') _delete(u);
                                    },
                                    itemBuilder: (menuCtx) {
                                      final menuScheme = Theme.of(menuCtx).colorScheme;
                                      return [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit_outlined, size: 18, color: menuScheme.onSurfaceVariant),
                                              const SizedBox(width: 10),
                                              Text(t.t('edit')),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'reset',
                                          child: Row(
                                            children: [
                                              const Icon(Icons.lock_reset_outlined, size: 18, color: Colors.orange),
                                              const SizedBox(width: 10),
                                              Text(t.t('resetPassword')),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                              const SizedBox(width: 10),
                                              Text(t.t('delete'), style: const TextStyle(color: Colors.redAccent)),
                                            ],
                                          ),
                                        ),
                                      ];
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(BuildContext context, {required String label, required String? value}) {
    final scheme = Theme.of(context).colorScheme;
    final selected = _typeFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _typeFilter = value);
        _load();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _kAccentBlue : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? Colors.transparent : scheme.outlineVariant),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}