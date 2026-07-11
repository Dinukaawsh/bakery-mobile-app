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
  final List<ShopDropItem> items;

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
    required this.items,
  });

  factory ShopDropSummary.fromJson(Map<String, dynamic> json) {
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
      items: (json['items'] as List)
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
