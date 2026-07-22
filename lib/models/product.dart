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

class PendingUnsoldLine {
  final String businessDate;
  final int productId;
  final String productName;
  final int quantity;

  const PendingUnsoldLine({
    required this.businessDate,
    required this.productId,
    required this.productName,
    required this.quantity,
  });

  factory PendingUnsoldLine.fromJson(Map<String, dynamic> json) {
    return PendingUnsoldLine(
      businessDate: json['businessDate'] as String,
      productId: json['productId'] as int,
      productName: json['productName'] as String,
      quantity: json['quantity'] as int,
    );
  }
}

class PendingDriverStock {
  final int deliveryGuyId;
  final String deliveryGuyName;
  final List<String> dates;
  final List<PendingUnsoldLine> items;
  final int totalRemaining;

  const PendingDriverStock({
    required this.deliveryGuyId,
    required this.deliveryGuyName,
    required this.dates,
    required this.items,
    required this.totalRemaining,
  });

  factory PendingDriverStock.fromJson(Map<String, dynamic> json) {
    return PendingDriverStock(
      deliveryGuyId: json['deliveryGuyId'] as int,
      deliveryGuyName: json['deliveryGuyName'] as String,
      dates: ((json['dates'] as List?) ?? [])
          .map((item) => item.toString())
          .toList(),
      items: ((json['items'] as List?) ?? [])
          .map(
            (item) => PendingUnsoldLine.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      totalRemaining: json['totalRemaining'] as int? ?? 0,
    );
  }
}
