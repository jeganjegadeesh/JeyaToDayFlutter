class CashPayment {
  final int id;
  final int retailerId;
  final String? retailerName;
  final String? retailerImage;
  final DateTime date;
  final double amount;
  final bool isBilled;

  CashPayment({
    required this.id,
    required this.retailerId,
    this.retailerName,
    this.retailerImage,
    required this.date,
    required this.amount,
    required this.isBilled,
  });

  factory CashPayment.fromJson(Map<String, dynamic> json) => CashPayment(
        id: json['id'],
        retailerId: json['retailer_id'],
        retailerName: json['retailer']?['name'],
        retailerImage: json['retailer']?['profile_image'],
        date: DateTime.parse(json['date']),
        amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
        isBilled: json['is_billed'] == true || json['is_billed'] == 1,
      );
}
