import 'product_model.dart';
import 'user_model.dart';

class StockEntryModel {
  final int id;
  final int retailerId;
  final String date;
  final UserModel? retailer;
  final List<StockEntryItemModel> items;

  StockEntryModel({
    required this.id,
    required this.retailerId,
    required this.date,
    this.retailer,
    required this.items,
  });

  factory StockEntryModel.fromJson(Map<String, dynamic> json) {
    return StockEntryModel(
      id: json['id'] ?? 0,
      retailerId: json['retailer_id'] ?? 0,
      date: json['date'] ?? '',
      retailer: json['retailer'] != null
          ? UserModel(
              id: json['retailer']['id'] ?? 0,
              name: json['retailer']['name'] ?? '',
              mobile: json['retailer']['mobile'] ?? '',
              role: json['retailer']['role'] ?? 'retailer',
              commission: double.tryParse(
                      json['retailer']['commission'].toString()) ??
                  0.0,
            )
          : null,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => StockEntryItemModel.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class StockEntryItemModel {
  final int id;
  final int stockEntryId;
  final int productId;
  final int quantity;
  final ProductModel? product;

  StockEntryItemModel({
    required this.id,
    required this.stockEntryId,
    required this.productId,
    required this.quantity,
    this.product,
  });

  factory StockEntryItemModel.fromJson(Map<String, dynamic> json) {
    return StockEntryItemModel(
      id: json['id'] ?? 0,
      stockEntryId: json['stock_entry_id'] ?? 0,
      productId: json['product_id'] ?? 0,
      quantity: json['quantity'] ?? 0,
      product: json['product'] != null
          ? ProductModel(
              id: json['product']['id'] ?? 0,
              name: json['product']['name'] ?? '',
              tamilName: json['product']['tamil_name'] ?? '',
              price: double.tryParse(
                      json['product']['price'].toString()) ??
                  0.0,
              category: json['product']['category'],
            )
          : null,
    );
  }
}