class UserModel {
  final int id;
  final String name;
  final String mobile;
  final String role;
  final double commission;

  UserModel({
    required this.id,
    required this.name,
    required this.mobile,
    required this.role,
    required this.commission,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      mobile: json['mobile'] ?? '',
      role: json['role'] ?? 'retailer',
      commission:
          double.tryParse(json['commission'].toString()) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mobile': mobile,
      'role': role,
      'commission': commission,
    };
  }

  bool get isAdmin => role == 'admin';
  bool get isRetailer => role == 'retailer';
  bool get isUser => role == 'user';
}