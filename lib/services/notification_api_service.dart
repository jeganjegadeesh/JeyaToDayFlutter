import '../config/network_url.dart';
import '../models/app_notification_item.dart';
import 'api_service.dart';

class NotificationApiService {
  static Future<List<AppNotificationItem>> list() async {
    final res = await ApiService.get(NetworkUrl.notifications);
    final List data = res['data'] ?? res;
    return data.map((e) => AppNotificationItem.fromJson(e)).toList();
  }

  static Future<int> unreadCount() async {
    final res = await ApiService.get(NetworkUrl.notificationsUnreadCount);
    return res['unread_count'] ?? 0;
  }

  static Future<int> markRead(int id) async {
    final res = await ApiService.post(NetworkUrl.notificationRead(id));
    return res['unread_count'] ?? 0;
  }

  static Future<void> markAllRead() async {
    await ApiService.post(NetworkUrl.notificationsReadAll);
  }
}
