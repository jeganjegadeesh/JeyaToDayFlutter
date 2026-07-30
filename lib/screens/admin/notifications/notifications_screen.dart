import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/app_notification_item.dart';
import '../../../services/api_service.dart';
import '../../../services/notification_api_service.dart';
import '../../../services/push_notification_service.dart';
import '../../../widgets/dialogs.dart';
import 'password_reset_requests_screen.dart';
import '../bills/bill_deep_link_screen.dart';


class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotificationItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _items = await NotificationApiService.list();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await NotificationApiService.markAllRead();
      await PushNotificationService.instance.refreshBadge();
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, isError: true);
    }
  }

  Future<void> _open(AppNotificationItem item) async {
    if (!item.isRead) {
      try {
        await NotificationApiService.markRead(item.id);
        await PushNotificationService.instance.refreshBadge();
        setState(() {
          final idx = _items.indexOf(item);
          if (idx != -1) {
            _items[idx] = AppNotificationItem(
              id: item.id,
              type: item.type,
              title: item.title,
              body: item.body,
              data: item.data,
              referenceId: item.referenceId,
              referenceType: item.referenceType,
              isRead: true,
              readAt: DateTime.now(),
              createdAt: item.createdAt,
            );
          }
        });
      } catch (_) {
        // non-fatal - still navigate even if marking read failed
      }
    }

    if (!mounted) return;
    switch (item.data['screen']) {
      case 'password_reset_requests':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PasswordResetRequestsScreen()));
        break;
      case 'bill_detail':
        final billId = int.tryParse('${item.data['bill_id']}');
        if (billId != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => BillDeepLinkScreen(billId: billId)));
        }
        break;
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'password_reset_request':
        return Icons.lock_reset;
      case 'new_bill':
        return Icons.receipt_long;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Mark all read', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _items.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No notifications yet')),
                      ],
                    )
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final item = _items[i];
                        return ListTile(
                          tileColor: item.isRead ? null : Theme.of(context).colorScheme.primary.withOpacity(0.06),
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                            child: Icon(_iconFor(item.type), color: Theme.of(context).colorScheme.primary),
                          ),
                          title: Text(
                            item.title,
                            style: TextStyle(fontWeight: item.isRead ? FontWeight.normal : FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${item.body}${item.createdAt != null ? '\n${DateFormat('dd-MM-yyyy hh:mm a').format(item.createdAt!)}' : ''}',
                          ),
                          isThreeLine: true,
                          trailing: item.isRead ? null : const Icon(Icons.circle, size: 10, color: Colors.red),
                          onTap: () => _open(item),
                        );
                      },
                    ),
            ),
    );
  }
}
