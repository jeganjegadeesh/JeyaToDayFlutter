class RawMaterial {
  final int id;
  final String name;

  RawMaterial({required this.id, required this.name});

  factory RawMaterial.fromJson(Map<String, dynamic> json) =>
      RawMaterial(id: json['id'], name: json['name'] ?? '');

  Map<String, dynamic> toJson() => {'name': name};
}

class Expense {
  final int id;
  final DateTime date;
  final double amount;
  final String? remarks;
  final List<RawMaterial> rawMaterials;

  Expense({
    required this.id,
    required this.date,
    required this.amount,
    this.remarks,
    required this.rawMaterials,
  });

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'],
        date: DateTime.parse(json['date']),
        amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
        remarks: json['remarks'],
        rawMaterials: (json['raw_materials'] as List? ?? [])
            .map((e) => RawMaterial.fromJson(e))
            .toList(),
      );
}

class RetailerLoan {
  final int id;
  final int retailerId;
  final String? retailerName;
  final double amount;
  final DateTime date;
  final String? remarks;

  RetailerLoan({
    required this.id,
    required this.retailerId,
    this.retailerName,
    required this.amount,
    required this.date,
    this.remarks,
  });

  factory RetailerLoan.fromJson(Map<String, dynamic> json) => RetailerLoan(
        id: json['id'],
        retailerId: json['retailer_id'],
        retailerName: json['retailer']?['name'],
        amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
        date: DateTime.parse(json['date']),
        remarks: json['remarks'],
      );
}
