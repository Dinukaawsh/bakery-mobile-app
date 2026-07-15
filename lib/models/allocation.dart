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
    );
  }
}
