class CashPaymentModel {
  final int id;
  final int retailerId;
  final String date;
  final double amount;
  final String? note;

  CashPaymentModel({
    required this.id,
    required this.retailerId,
    required this.date,
    required this.amount,
    this.note,
  });

  factory CashPaymentModel.fromJson(Map<String, dynamic> json) {
    return CashPaymentModel(
      id: json['id'] ?? 0,
      retailerId: json['retailer_id'] ?? 0,
      date: json['date'] ?? '',
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      note: json['note'],
    );
  }
}