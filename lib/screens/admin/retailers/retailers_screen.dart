import 'dart:io';
import 'package:aj_project/config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../config/network_url.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/retailer.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/crud_service.dart';
import '../../../services/api_service.dart';
import '../../../widgets/dialogs.dart';

// Brand accent - stays constant across light/dark, everything else reads
// from Theme.of(context).colorScheme so the screen adapts automatically.
const _kAccentBlue = Color(0xFF3B82F6);
const _kCommissionAccent = Color(0xFF10B981);

class RetailersScreen extends ConsumerStatefulWidget {
  const RetailersScreen({super.key});

  @override
  ConsumerState<RetailersScreen> createState() => _RetailersScreenState();
}

class _RetailersScreenState extends ConsumerState<RetailersScreen> {
  final _service = CrudService<Retailer>(NetworkUrl.retailers, Retailer.fromJson);
  List<Retailer> _items = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _service.list(query: {if (_search.isNotEmpty) 'search': _search});
      setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitRetailer({
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

  void _openForm({Retailer? existing}) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phoneNumber ?? '');
    final commissionCtrl = TextEditingController(text: existing?.commission.toString() ?? '');
    XFile? pickedImage;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            existing == null ? t.t('addRetailer') : t.t('editRetailer'),
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
                              ? Icon(Icons.storefront_outlined, size: 36, color: scheme.primary)
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
                    decoration: _fieldDecoration(context, t.t('name'), Icons.storefront_outlined),
                    validator: (v) => (v == null || v.isEmpty) ? t.t('required') : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: _fieldDecoration(context, t.t('phoneNumber'), Icons.phone_outlined),
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v == null || v.isEmpty) ? t.t('required') : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: commissionCtrl,
                    decoration: _fieldDecoration(context, t.t('commission'), Icons.percent_outlined).copyWith(
                      hintText: 'e.g. 50',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => (v == null || double.tryParse(v) == null) ? t.t('validPercent') : null,
                  ),
                  if (existing == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        t.t('autoAccountHint'),
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
                  'phone_number': phoneCtrl.text.trim(),
                  'commission': commissionCtrl.text.trim(),
                };
                try {
                  await _submitRetailer(
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

  /// Places a normal phone call to the retailer's registered number using
  /// the device dialer (tel: scheme) — no in-app calling involved.
  Future<void> _call(Retailer r) async {
    final t = context.l10n;
    final uri = Uri(scheme: 'tel', path: r.phoneNumber);
    try {
      final launched = await launchUrl(uri);
      if (!launched && mounted) showSnack(context, t.t('callNotAvailable'), isError: true);
    } catch (_) {
      if (mounted) showSnack(context, t.t('callNotAvailable'), isError: true);
    }
  }

  Future<void> _delete(Retailer r) async {
    final t = context.l10n;
    final ok = await confirmDialog(
      context,
      title: t.t('deleteRetailer'),
      message: '${t.t('deleteRetailerConfirm')} "${r.name}"',
    );
    if (!ok) return;
    try {
      await _service.delete(r.id);
      _load();
    } on ApiException catch (e) {
      showSnack(context, e.message, isError: true);
    }
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

  Color _commissionBg(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _kCommissionAccent.withValues(alpha: isDark ? 0.22 : 0.12);
  }

  Color _commissionText(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Color.lerp(_kCommissionAccent, Colors.white, 0.25)! : _kCommissionAccent;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final isAdmin = ref.watch(authProvider).user!.isAdmin;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: _kAccentBlue,
        shape: const CircleBorder(),
        onPressed: () => _openForm(),
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
          const SizedBox(height: 4),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _kAccentBlue))
                : _items.isEmpty
                    ? Center(
                        child: Text(
                          t.t('noRetailersFound'),
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
                            final r = _items[i];
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
                                    backgroundImage: r.profileImage != null
                                        ? NetworkImage('${ApiConfig.imageBaseUrl}/${r.profileImage!}')
                                        : null,
                                    child: r.profileImage == null
                                        ? Text(
                                            r.name.isNotEmpty ? r.name[0].toUpperCase() : '?',
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
                                                r.name,
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
                                                color: _commissionBg(context),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                '${r.commission.toStringAsFixed(0)}%',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: _commissionText(context),
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
                                              r.phoneNumber,
                                              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _call(r),
                                    tooltip: t.t('call'),
                                    icon: const Icon(Icons.call, color: _kAccentBlue),
                                    style: IconButton.styleFrom(
                                      backgroundColor: _kAccentBlue.withValues(alpha: 0.10),
                                      shape: const CircleBorder(),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert, color: scheme.outline),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    onSelected: (v) {
                                      if (v == 'edit') _openForm(existing: r);
                                      if (v == 'delete') _delete(r);
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
                                        if (isAdmin)
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
}