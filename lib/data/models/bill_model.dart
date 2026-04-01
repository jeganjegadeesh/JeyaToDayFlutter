import 'product_model.dart';
import 'user_model.dart';

class BillModel {
  final int id;
  final int retailerId;
  final String date;
  final String? fromDate;
  final String? toDate;
  final double totalSales;
  final double commission;
  final double finalAmount;
  final double paidAmount;
  final double balanceAmount;
  final UserModel? retailer;
  final List<BillItemModel> items;

  BillModel({
    required this.id,
    required this.retailerId,
    required this.date,
    this.fromDate,
    this.toDate,
    required this.totalSales,
    required this.commission,
    required this.finalAmount,
    this.paidAmount = 0,
    this.balanceAmount = 0,
    this.retailer,
    required this.items,
  });

  factory BillModel.fromJson(Map<String, dynamic> json) {
    return BillModel(
      id: json['id'] ?? 0,
      retailerId: json['retailer_id'] ?? 0,
      date: json['date'] ?? '',
      fromDate: json['from_date'],
      toDate: json['to_date'],
      totalSales: double.tryParse(json['total_sales'].toString()) ?? 0.0,
      commission: double.tryParse(json['commission'].toString()) ?? 0.0,
      finalAmount: double.tryParse(json['final_amount'].toString()) ?? 0.0,
      paidAmount: double.tryParse(json['paid_amount']?.toString() ?? '0') ?? 0.0,
      balanceAmount: double.tryParse(json['balance_amount']?.toString() ?? '0') ?? 0.0,
      retailer: json['retailer'] != null
          ? UserModel(
              id: json['retailer']['id'] ?? 0,
              name: json['retailer']['name'] ?? '',
              mobile: json['retailer']['mobile'] ?? '',
              role: json['retailer']['role'] ?? 'retailer',
              commission: double.tryParse(json['retailer']['commission'].toString()) ?? 0.0,
            )
          : null,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => BillItemModel.fromJson(e))
              .toList() ?? [],
    );
  }
}

class BillItemModel {
  final int id;
  final int billId;
  final int productId;
  final int givenQty;
  final int returnedQty;
  final int soldQty;
  final double price;
  final double amount;
  final ProductModel? product;

  BillItemModel({
    required this.id,
    required this.billId,
    required this.productId,
    required this.givenQty,
    required this.returnedQty,
    required this.soldQty,
    required this.price,
    required this.amount,
    this.product,
  });

  factory BillItemModel.fromJson(Map<String, dynamic> json) {
    return BillItemModel(
      id: json['id'] ?? 0,
      billId: json['bill_id'] ?? 0,
      productId: json['product_id'] ?? 0,
      givenQty: json['given_qty'] ?? 0,
      returnedQty: json['returned_qty'] ?? 0,
      soldQty: json['sold_qty'] ?? 0,
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      product: json['product'] != null
          ? ProductModel(
              id: json['product']['id'] ?? 0,
              name: json['product']['name'] ?? '',
              tamilName: json['product']['tamil_name'],
              price: double.tryParse(json['product']['price'].toString()) ?? 0.0,
              category: json['product']['category'],
            )
          : null,
    );
  }
}