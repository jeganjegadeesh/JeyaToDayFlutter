class ProductModel {
  final int id;
  final String name;
  final String tamilName;
  final double price;
  final String? category;

  ProductModel({
    required this.id,
    required this.name,
    required this.tamilName,
    required this.price,
    this.category,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      tamilName: json['tamil_name'] ?? '',
      price:
          double.tryParse(json['price'].toString()) ?? 0.0,
      category: json['category'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'tamil_name': tamilName,
      'price': price,
      'category': category,
    };
  }
}