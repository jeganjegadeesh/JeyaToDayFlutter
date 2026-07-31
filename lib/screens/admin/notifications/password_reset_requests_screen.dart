import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/password_reset_request_item.dart';
import '../../../services/api_service.dart';
import '../../../services/password_reset_request_service.dart';
import '../../../widgets/dialogs.dart';

/// Admin-only. Shows every "forgot password" request raised by managers /
/// retailers (one per phone number per day - enforced server-side) and lets
/// the admin reset that user's password back to the system default.
class PasswordResetRequestsScreen extends StatefulWidget {
  const PasswordResetRequestsScreen({super.key});

  @override
  State<PasswordResetRequestsScreen> createState() => _PasswordResetRequestsScreenState();
}

class _PasswordResetRequestsScreenState extends State<PasswordResetRequestsScreen> {
  List<PasswordResetRequestItem> _items = [];
  bool _loading = true;
  String? _statusFilter = 'pending';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await PasswordResetRequestService.list(status: _statusFilter);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resolve(PasswordResetRequestItem item) async {
    final t = context.l10n;
    final ok = await confirmDialog(
      context,
      title: t.t('resetPasswordTitle'),
      message: t.t('resetPasswordConfirmMessage').replaceAll('{name}', item.userName ?? item.phoneNumber),
    );
    if (!ok) return;
    try {
      final message = await PasswordResetRequestService.resolve(item.id);
      if (mounted) showSnack(context, message);
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.t('passwordResetRequests')),
        actions: [
          PopupMenuButton<String?>(
            initialValue: _statusFilter,
            onSelected: (v) {
              setState(() => _statusFilter = v);
              _load();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'pending', child: Text(t.t('pending'))),
              PopupMenuItem(value: 'resolved', child: Text(t.t('resolved'))),
              PopupMenuItem(value: null, child: Text(t.t('all'))),
            ],
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(child: Text(t.t('noRequestsHere'))),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final item = _items[i];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: item.isPending ? Colors.orange.shade100 : Colors.green.shade100,
                              child: Icon(
                                item.isPending ? Icons.lock_reset : Icons.check_circle_outline,
                                color: item.isPending ? Colors.orange.shade800 : Colors.green.shade800,
                              ),
                            ),
                            title: Text(item.userName ?? item.phoneNumber),
                            subtitle: Text(
                              '${item.phoneNumber}${item.userType != null ? ' · ${item.userType}' : ''}\n'
                              '${t.t('requestedOn')} ${DateFormat('dd-MM-yyyy hh:mm a').format(item.requestedAt)}',
                            ),
                            isThreeLine: true,
                            trailing: item.isPending
                                ? FilledButton(
                                    onPressed: () => _resolve(item),
                                    child: Text(t.t('reset')),
                                  )
                                : Chip(label: Text(t.t('resolved'))),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
