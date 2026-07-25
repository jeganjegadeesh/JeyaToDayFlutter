class Company {
  final int id;
  final String name;
  final String? logo;
  final String? gstNumber;
  final String? fullAddress;
  final String? contactNumber;
  final double openingBalance;
  final bool isSetupComplete;

  Company({
    required this.id,
    required this.name,
    this.logo,
    this.gstNumber,
    this.fullAddress,
    this.contactNumber,
    required this.openingBalance,
    this.isSetupComplete = false,
  });

  factory Company.fromJson(Map<String, dynamic> json) => Company(
        id: json['id'],
        name: json['name'] ?? '',
        logo: json['logo'],
        gstNumber: json['gst_number'],
        fullAddress: json['full_address'],
        contactNumber: json['contact_number'],
        openingBalance: double.tryParse('${json['opening_balance'] ?? 0}') ?? 0,
        isSetupComplete: json['is_setup_complete'] == true || json['is_setup_complete'] == 1,
      );
}