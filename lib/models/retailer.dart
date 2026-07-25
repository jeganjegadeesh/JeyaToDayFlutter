class Retailer {
  final int id;
  final String name;
  final String phoneNumber;
  final double commission;
  final String? profileImage;

  Retailer({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.commission,
    this.profileImage
  });

  factory Retailer.fromJson(Map<String, dynamic> json) => Retailer(
        id: json['id'],
        name: json['name'] ?? '',
        phoneNumber: json['phone_number'] ?? '',
        commission: double.tryParse('${json['commission'] ?? 0}') ?? 0,
        profileImage: json['profile_image']
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone_number': phoneNumber,
        'commission': commission,
      };
}
