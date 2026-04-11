class ProductModel {
  final int id;
  final String name;
  final double price;
  final String? category;

  ProductModel({
    required this.id,
    required this.name,
    required this.price,
    this.category,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      price:
          double.tryParse(json['price'].toString()) ?? 0.0,
      category: json['category'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'category': category,
    };
  }
}