class Product {
  final int id;
  final String name;
  final String? description;
  final String price;
  final String category;
  final int stockAvailable;
  final String? imageUrl;
  final bool isActive;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.stockAvailable,
    this.imageUrl,
    required this.isActive,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      price: json['price'] as String,
      category: json['category'] as String,
      stockAvailable: json['stockAvailable'] as int,
      imageUrl: json['imageUrl'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class ProductInput {
  final String name;
  final String? description;
  final String price;
  final String category;
  final int stockAvailable;

  const ProductInput({
    required this.name,
    this.description,
    required this.price,
    this.category = 'general',
    this.stockAvailable = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (description != null && description!.isNotEmpty)
        'description': description,
      'price': price,
      'category': category,
      'stockAvailable': stockAvailable,
    };
  }
}
