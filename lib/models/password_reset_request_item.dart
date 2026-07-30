class PasswordResetRequestItem {
  final int id;
  final int? userId;
  final String? userName;
  final String? userType;
  final String phoneNumber;
  final String status; // 'pending' | 'resolved'
  final DateTime requestedAt;
  final DateTime? resolvedAt;

  PasswordResetRequestItem({
    required this.id,
    this.userId,
    this.userName,
    this.userType,
    required this.phoneNumber,
    required this.status,
    required this.requestedAt,
    this.resolvedAt,
  });

  bool get isPending => status == 'pending';

  factory PasswordResetRequestItem.fromJson(Map<String, dynamic> json) => PasswordResetRequestItem(
        id: json['id'],
        userId: json['user']?['id'] ?? json['user_id'],
        userName: json['user']?['name'],
        userType: json['user']?['type'],
        phoneNumber: json['phone_number'] ?? '',
        status: json['status'] ?? 'pending',
        requestedAt: DateTime.parse(json['requested_at']),
        resolvedAt: json['resolved_at'] != null ? DateTime.tryParse('${json['resolved_at']}') : null,
      );
}
