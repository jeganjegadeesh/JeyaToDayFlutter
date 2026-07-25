import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/network_url.dart';
import '../../../models/misc_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/crud_service.dart';
import '../../../services/api_service.dart';
import '../../../widgets/dialogs.dart';

class RawMaterialsScreen extends ConsumerStatefulWidget {
  const RawMaterialsScreen({super.key});

  @override
  ConsumerState<RawMaterialsScreen> createState() => _RawMaterialsScreenState();
}

class _RawMaterialsScreenState extends ConsumerState<RawMaterialsScreen> {
  final _service = CrudService<RawMaterial>(NetworkUrl.rawMaterials, RawMaterial.fromJson);
  List<RawMaterial> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _service.list();
      setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openForm({RawMaterial? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Raw Material' : 'Edit Raw Material'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Raw Material Name'),
            validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                if (existing == null) {
                  await _service.create({'name': nameCtrl.text.trim()});
                } else {
                  await _service.update(existing.id, {'name': nameCtrl.text.trim()});
                }
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              } on ApiException catch (e) {
                showSnack(ctx, e.message, isError: true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(RawMaterial m) async {
    final ok = await confirmDialog(context, title: 'Delete', message: 'Delete "${m.name}"?');
    if (!ok) return;
    try {
      await _service.delete(m.id);
      _load();
    } on ApiException catch (e) {
      showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(authProvider).user!.isAdmin;
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? const Center(child: Text('No raw materials yet'))
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final m = _items[i];
                        return ListTile(
                          title: Text(m.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit), onPressed: () => _openForm(existing: m)),
                              if (isAdmin)
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _delete(m)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(onPressed: () => _openForm(), child: const Icon(Icons.add)),
    );
  }
}
