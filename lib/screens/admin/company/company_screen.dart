import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../config/api_config.dart';
import '../../../config/network_url.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/company.dart';
import '../../../services/api_service.dart';
import '../../../widgets/dialogs.dart';

const _kAccentBlue = Color(0xFF3B82F6);

class CompanyScreen extends StatefulWidget {
  /// When true, this screen is being shown as the mandatory first-login
  /// setup step (its own app bar + welcome copy, no drawer/bottom nav
  /// since it isn't hosted inside a shell) rather than as the normal
  /// "Company Setup" tab under Creations.
  final bool onboarding;

  /// Called after a successful save when [onboarding] is true, so the
  /// caller can refresh the signed-in user and unlock the real dashboard.
  final VoidCallback? onSaved;

  const CompanyScreen({super.key, this.onboarding = false, this.onSaved});

  @override
  State<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
  Company? _company;
  bool _loading = true;
  bool _saving = false;

  XFile? _pickedLogo;

  final _nameCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _openingBalanceCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.get(NetworkUrl.company);
      _company = Company.fromJson(res);
      _nameCtrl.text = _company!.name;
      _gstCtrl.text = _company!.gstNumber ?? '';
      _addressCtrl.text = _company!.fullAddress ?? '';
      _contactCtrl.text = _company!.contactNumber ?? '';
      _openingBalanceCtrl.text = _company!.openingBalance.toString();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickLogo() async {
    final t = context.l10n;
    final picker = ImagePicker();
    final result = await showModalBottomSheet<XFile?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
    if (result != null) setState(() => _pickedLogo = result);
  }

  Future<void> _save() async {
    final t = context.l10n;
    setState(() => _saving = true);
    try {
      final fields = {
        'name': _nameCtrl.text.trim(),
        'gst_number': _gstCtrl.text.trim(),
        'full_address': _addressCtrl.text.trim(),
        'contact_number': _contactCtrl.text.trim(),
        'opening_balance': double.tryParse(_openingBalanceCtrl.text) ?? 0,
      };

      if (_pickedLogo == null) {
        await ApiService.put(NetworkUrl.companyById(_company!.id), body: fields);
      } else {
        // Multipart upload requires string fields + the file itself.
        await ApiService.multipart(
          NetworkUrl.companyById(_company!.id),
          fields: fields.map((k, v) => MapEntry(k, '$v')),
          fileField: 'logo',
          filePath: _pickedLogo!.path,
          method: 'PUT',
        );
      }

      if (mounted) showSnack(context, t.t('companySaved'));
      _pickedLogo = null;
      await _load();
      if (widget.onboarding) widget.onSaved?.call();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: widget.onboarding
          ? AppBar(title: Text(t.t('companySetup')), automaticallyImplyLeading: false)
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.onboarding) ...[
                  Text(
                    t.t('companySetupWelcomeTitle'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.t('companySetupWelcomeHint'),
                    style: const TextStyle(color: Colors.grey),
                  ),
                ] else
                  Text(
                    t.t('companyDetailsHint'),
                    style: const TextStyle(color: Colors.grey),
                  ),
                const SizedBox(height: 20),
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: scheme.primaryContainer,
                        backgroundImage: _pickedLogo != null
                            ? FileImage(File(_pickedLogo!.path)) as ImageProvider
                            : (_company?.logo != null
                                ? NetworkImage('${ApiConfig.imageBaseUrl}/${_company!.logo!}')
                                : null),
                        child: (_pickedLogo == null && _company?.logo == null)
                            ? Icon(Icons.storefront_outlined, size: 40, color: scheme.primary)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickLogo,
                          child: const CircleAvatar(
                            radius: 16,
                            backgroundColor: _kAccentBlue,
                            child: Icon(Icons.edit, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Center(
                  child: TextButton.icon(
                    onPressed: _pickLogo,
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: Text(t.t('changeCompanyLogo')),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(labelText: t.t('companyName'), border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _gstCtrl,
                  decoration: InputDecoration(labelText: t.t('gstNumber'), border: const OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressCtrl,
                  decoration: InputDecoration(labelText: t.t('fullAddress'), border: const OutlineInputBorder()),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _contactCtrl,
                  decoration: InputDecoration(labelText: t.t('contactNumber'), border: const OutlineInputBorder()),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _openingBalanceCtrl,
                  decoration: InputDecoration(
                    labelText: t.t('openingBalance'),
                    helperText: t.t('openingBalanceHint'),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(widget.onboarding ? t.t('completeSetup') : t.t('save')),
                ),
              ],
            ),
    );
  }
}