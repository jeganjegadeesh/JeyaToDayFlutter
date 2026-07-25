class BillItem {
  final int? productId;
  final String productName;
  final double givenQty;
  final double returnedQty;
  final double soldQty;
  final double rate;
  final double amount;

  BillItem({
    this.productId,
    required this.productName,
    required this.givenQty,
    required this.returnedQty,
    required this.soldQty,
    required this.rate,
    required this.amount,
  });

  /// Handles both the /bills/preview shape (line_items) and the persisted
  /// Bill->items relation shape (bill_items table + product relation).
  factory BillItem.fromJson(Map<String, dynamic> json) => BillItem(
        productId: json['product_id'],
        productName: json['product_name'] ?? json['product']?['name'] ?? '',
        givenQty: double.tryParse('${json['given_qty'] ?? 0}') ?? 0,
        returnedQty: double.tryParse('${json['returned_qty'] ?? 0}') ?? 0,
        soldQty: double.tryParse('${json['sold_qty'] ?? 0}') ?? 0,
        rate: double.tryParse('${json['rate'] ?? 0}') ?? 0,
        amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
      );
}

class Bill {
  final int? id;
  final int retailerId;
  final String? retailerName;
  final String? retailerImage;
  final DateTime date;
  final List<BillItem> items;
  final double subtotal;
  final double commissionPercent;
  final double commissionAmount;
  final double finalTotal;
  final double cashPaid;
  final double grandTotal;
  final double settledAmount;

  Bill({
    this.id,
    required this.retailerId,
    this.retailerName,
    this.retailerImage,
    required this.date,
    required this.items,
    required this.subtotal,
    required this.commissionPercent,
    required this.commissionAmount,
    required this.finalTotal,
    required this.cashPaid,
    required this.grandTotal,
    this.settledAmount = 0,
  });

  factory Bill.fromJson(Map<String, dynamic> json) => Bill(
        id: json['id'],
        retailerId: json['retailer_id'],
        retailerName: json['retailer_name'] ?? json['retailer']?['name'],
        retailerImage: json['retailer_image'] ?? json['retailer']?['profile_image'],
        date: DateTime.parse(json['date']),
        items: (json['line_items'] ?? json['items'] as List? ?? [])
            .map<BillItem>((e) => BillItem.fromJson(e))
            .toList(),
        subtotal: double.tryParse('${json['subtotal'] ?? 0}') ?? 0,
        commissionPercent: double.tryParse('${json['commission_percent'] ?? 0}') ?? 0,
        commissionAmount: double.tryParse('${json['commission_amount'] ?? 0}') ?? 0,
        finalTotal: double.tryParse('${json['final_total'] ?? 0}') ?? 0,
        cashPaid: double.tryParse('${json['cash_paid'] ?? 0}') ?? 0,
        grandTotal: double.tryParse('${json['grand_total'] ?? 0}') ?? 0,
        settledAmount: double.tryParse('${json['settled_amount'] ?? 0}') ?? 0,
      );
}