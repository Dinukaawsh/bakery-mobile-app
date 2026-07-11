class Sale {
  final int id;
  final int deliveryGuyId;
  final int shopId;
  final DateTime saleDate;
  final String totalAmount;
  final String? notes;
  final bool billPrinted;
  final String shopName;
  final String deliveryGuyName;
  final String? shopOwner;
  final String? shopAddress;
  final String? shopPhone;
  final List<SaleItem> items;

  const Sale({
    required this.id,
    required this.deliveryGuyId,
    required this.shopId,
    required this.saleDate,
    required this.totalAmount,
    required this.notes,
    required this.billPrinted,
    required this.shopName,
    required this.deliveryGuyName,
    this.shopOwner,
    this.shopAddress,
    this.shopPhone,
    this.items = const [],
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return Sale(
      id: json['id'] as int,
      deliveryGuyId: json['deliveryGuyId'] as int,
      shopId: json['shopId'] as int,
      saleDate: DateTime.parse(json['saleDate'] as String),
      totalAmount: json['totalAmount'] as String,
      notes: json['notes'] as String?,
      billPrinted: json['billPrinted'] as bool? ?? false,
      shopName: json['shopName'] as String? ?? '',
      deliveryGuyName: json['deliveryGuyName'] as String? ?? '',
      shopOwner: json['shopOwner'] as String?,
      shopAddress: json['shopAddress'] as String?,
      shopPhone: json['shopPhone'] as String?,
      items: rawItems is List
          ? rawItems
              .map((item) => SaleItem.fromJson(item as Map<String, dynamic>))
              .toList()
          : const [],
    );
  }
}

class SaleItem {
  final int id;
  final int productId;
  final int quantity;
  final String unitPrice;
  final String productName;

  const SaleItem({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.productName,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      id: json['id'] as int,
      productId: json['productId'] as int,
      quantity: json['quantity'] as int,
      unitPrice: json['unitPrice'] as String,
      productName: json['productName'] as String? ?? '',
    );
  }
}

class SaleInput {
  final int shopId;
  final String saleDate;
  final String? notes;
  final List<Map<String, int>> items;

  const SaleInput({
    required this.shopId,
    required this.saleDate,
    this.notes,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'shopId': shopId,
      'saleDate': saleDate,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      'items': items,
    };
  }
}
