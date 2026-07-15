class ShopDropItem {
  final int productId;
  final String productName;
  final int quantity;
  final String unitPrice;

  const ShopDropItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  factory ShopDropItem.fromJson(Map<String, dynamic> json) {
    return ShopDropItem(
      productId: json['productId'] as int,
      productName: json['productName'] as String,
      quantity: json['quantity'] as int,
      unitPrice: json['unitPrice'] as String,
    );
  }
}

class ShopDropSale {
  final int id;
  final DateTime saleDate;
  final String totalAmount;
  final bool billPrinted;
  final List<ShopDropItem> items;

  const ShopDropSale({
    required this.id,
    required this.saleDate,
    required this.totalAmount,
    required this.billPrinted,
    required this.items,
  });

  factory ShopDropSale.fromJson(Map<String, dynamic> json) {
    return ShopDropSale(
      id: json['id'] as int,
      saleDate: DateTime.parse(json['saleDate'] as String),
      totalAmount: json['totalAmount'] as String,
      billPrinted: json['billPrinted'] as bool? ?? false,
      items: ((json['items'] as List?) ?? [])
          .map((item) => ShopDropItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  String get itemsLabel {
    return items
        .map((item) => '${item.productName} × ${item.quantity}')
        .join(', ');
  }
}

class ShopDropSummary {
  final int shopId;
  final String shopName;
  final String shopOwner;
  final String shopAddress;
  final int deliveryGuyId;
  final String deliveryGuyName;
  final String dropDate;
  final int totalQuantity;
  final String totalAmount;
  final int saleCount;
  final List<ShopDropItem> items;
  final List<ShopDropSale> sales;

  const ShopDropSummary({
    required this.shopId,
    required this.shopName,
    required this.shopOwner,
    required this.shopAddress,
    required this.deliveryGuyId,
    required this.deliveryGuyName,
    required this.dropDate,
    required this.totalQuantity,
    required this.totalAmount,
    required this.saleCount,
    required this.items,
    required this.sales,
  });

  factory ShopDropSummary.fromJson(Map<String, dynamic> json) {
    final salesJson = (json['sales'] as List?) ?? [];
    return ShopDropSummary(
      shopId: json['shopId'] as int,
      shopName: json['shopName'] as String,
      shopOwner: json['shopOwner'] as String,
      shopAddress: json['shopAddress'] as String,
      deliveryGuyId: json['deliveryGuyId'] as int,
      deliveryGuyName: json['deliveryGuyName'] as String,
      dropDate: json['dropDate'] as String,
      totalQuantity: json['totalQuantity'] as int,
      totalAmount: json['totalAmount'] as String,
      saleCount: json['saleCount'] as int? ?? salesJson.length,
      items: (json['items'] as List)
          .map((item) => ShopDropItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      sales: salesJson
          .map((item) => ShopDropSale.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  String get itemsLabel {
    return items
        .map((item) => '${item.productName} × ${item.quantity}')
        .join(', ');
  }
}
