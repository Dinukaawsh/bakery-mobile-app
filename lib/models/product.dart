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

/// Product previously dropped at a shop, with net returnable qty.
class ReturnableProduct {
  final int productId;
  final String productName;
  final String productPrice;
  final String? productDescription;
  final String productCategory;
  final String? productImageUrl;
  final bool isActive;
  final int dropped;
  final int returned;
  final int returnable;

  const ReturnableProduct({
    required this.productId,
    required this.productName,
    required this.productPrice,
    this.productDescription,
    required this.productCategory,
    this.productImageUrl,
    required this.isActive,
    required this.dropped,
    required this.returned,
    required this.returnable,
  });

  factory ReturnableProduct.fromJson(Map<String, dynamic> json) {
    return ReturnableProduct(
      productId: json['productId'] as int,
      productName: json['productName'] as String,
      productPrice: json['productPrice']?.toString() ?? '0',
      productDescription: json['productDescription'] as String?,
      productCategory: json['productCategory'] as String? ?? '',
      productImageUrl: json['productImageUrl'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      dropped: json['dropped'] as int? ?? 0,
      returned: json['returned'] as int? ?? 0,
      returnable: json['returnable'] as int? ?? 0,
    );
  }
}
