class Product {
  final int id;
  final String name;
  final String type; // retail | bulk | both
  final double rate;

  Product({required this.id, required this.name, required this.type, required this.rate});

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'],
        name: json['name'] ?? '',
        type: json['type'] ?? 'retail',
        rate: double.tryParse('${json['rate'] ?? 0}') ?? 0,
      );

  Map<String, dynamic> toJson() => {'name': name, 'type': type, 'rate': rate};
}
