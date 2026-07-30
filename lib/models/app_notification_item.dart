class AppNotificationItem {
  final int id; // recipient row id (used for mark-as-read)
  final String type; // 'password_reset_request' | 'new_bill'
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final int? referenceId;
  final String? referenceType;
  final bool isRead;
  final DateTime? readAt;
  final DateTime? createdAt;

  AppNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    this.referenceId,
    this.referenceType,
    required this.isRead,
    this.readAt,
    this.createdAt,
  });

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) => AppNotificationItem(
        id: json['id'],
        type: json['type'] ?? '',
        title: json['title'] ?? '',
        body: json['body'] ?? '',
        data: Map<String, dynamic>.from(json['data'] ?? {}),
        referenceId: json['reference_id'],
        referenceType: json['reference_type'],
        isRead: json['is_read'] == true,
        readAt: json['read_at'] != null ? DateTime.tryParse('${json['read_at']}') : null,
        createdAt: json['created_at'] != null ? DateTime.tryParse('${json['created_at']}') : null,
      );
}
