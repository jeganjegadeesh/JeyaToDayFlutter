class StockItem {
  final int? productId;
  final String? productName;
  final double quantity;

  StockItem({this.productId, this.productName, required this.quantity});

  factory StockItem.fromJson(Map<String, dynamic> json) => StockItem(
        productId: json['product_id'],
        productName: json['product']?['name'],
        quantity: double.tryParse('${json['quantity'] ?? 0}') ?? 0,
      );

  Map<String, dynamic> toJson() => {'product_id': productId, 'quantity': quantity};
}

/// Represents either a give_stock or return_stock header record.
class StockEntry {
  final int id;
  final int retailerId;
  final String? retailerName;
  final String? retailerImage;
  final DateTime date;
  final bool isBilled;
  final List<StockItem> items;

  StockEntry({
    required this.id,
    required this.retailerId,
    this.retailerName,
    this.retailerImage,
    required this.date,
    required this.isBilled,
    required this.items,
  });

  factory StockEntry.fromJson(Map<String, dynamic> json) => StockEntry(
        id: json['id'],
        retailerId: json['retailer_id'],
        retailerName: json['retailer']?['name'],
        retailerImage: json['retailer']?['profile_image'],
        date: DateTime.parse(json['date']),
        isBilled: json['is_billed'] == true || json['is_billed'] == 1,
        items: (json['items'] as List? ?? []).map((e) => StockItem.fromJson(e)).toList(),
      );
}
