import 'company.dart';

class AppUser {
  final int id;
  final int? companyId;
  final String name;
  final String phoneNumber;
  final String type; // admin | manager | retailer
  final double? commission;
  final String theme;
  final String language;
  final String fontSize;
  final Company? company;
  final String? profileImage;
  final String? profileImageUrl;
  final DateTime? createdAt;

  AppUser({
    required this.id,
    this.companyId,
    required this.name,
    required this.phoneNumber,
    required this.type,
    this.commission,
    this.theme = 'light',
    this.language = 'ta',
    this.fontSize = 'M',
    this.company,
    this.profileImage,
    this.profileImageUrl,
    this.createdAt,
  });

  bool get isAdmin => type == 'admin';
  bool get isManager => type == 'manager';
  bool get isRetailer => type == 'retailer';
  bool get canManage => isAdmin || isManager;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'],
        companyId: json['company_id'],
        name: json['name'] ?? '',
        phoneNumber: json['phone_number'] ?? '',
        type: json['type'] ?? 'manager',
        commission: json['commission'] != null ? double.tryParse('${json['commission']}') : null,
        theme: json['theme'] ?? 'light',
        language: json['language'] ?? 'ta',
        fontSize: json['font_size'] ?? 'M',
        company: json['company'] != null ? Company.fromJson(json['company']) : null,
        profileImage: json['profile_image'],
        profileImageUrl: json['profile_image_url'],
        createdAt: json['created_at'] != null ? DateTime.tryParse('${json['created_at']}') : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone_number': phoneNumber,
        'type': type,
      };
}