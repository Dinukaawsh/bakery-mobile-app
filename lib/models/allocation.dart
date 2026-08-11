class ReturnShopLine {
  final int shopId;
  final String shopName;
  final int quantity;

  const ReturnShopLine({
    required this.shopId,
    required this.shopName,
    required this.quantity,
  });

  factory ReturnShopLine.fromJson(Map<String, dynamic> json) {
    return ReturnShopLine(
      shopId: json['shopId'] as int,
      shopName: json['shopName'] as String,
      quantity: json['quantity'] as int,
    );
  }
}

class AllocationSummary {
  final int deliveryGuyId;
  final String deliveryGuyName;
  final int productId;
  final String productName;
  final String? productDescription;
  final String? productPrice;
  final String? productCategory;
  final String? productImageUrl;
  final int allocated;
  final int sold;
  final int remaining;
  final int returned;
  final List<ReturnShopLine> returnShops;

  const AllocationSummary({
    required this.deliveryGuyId,
    required this.deliveryGuyName,
    required this.productId,
    required this.productName,
    this.productDescription,
    this.productPrice,
    this.productCategory,
    this.productImageUrl,
    required this.allocated,
    required this.sold,
    required this.remaining,
    this.returned = 0,
    this.returnShops = const [],
  });

  factory AllocationSummary.fromJson(Map<String, dynamic> json) {
    return AllocationSummary(
      deliveryGuyId: json['deliveryGuyId'] as int,
      deliveryGuyName: json['deliveryGuyName'] as String,
      productId: json['productId'] as int,
      productName: json['productName'] as String,
      productDescription: json['productDescription'] as String?,
      productPrice: json['productPrice']?.toString(),
      productCategory: json['productCategory'] as String?,
      productImageUrl: json['productImageUrl'] as String?,
      allocated: json['allocated'] as int,
      sold: json['sold'] as int,
      remaining: json['remaining'] as int,
      returned: json['returned'] as int? ?? 0,
      returnShops: ((json['returnShops'] as List?) ?? [])
          .map(
            (item) => ReturnShopLine.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
