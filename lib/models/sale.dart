class Sale {
  final int id;
  final int deliveryGuyId;
  final int shopId;
  final DateTime saleDate;
  final String totalAmount;
  final String previousBalance;
  final String paidAmount;
  final String remainingAfter;
  final String amountDue;
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
    required this.previousBalance,
    required this.paidAmount,
    required this.remainingAfter,
    required this.amountDue,
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
    final total = json['totalAmount']?.toString() ?? '0';
    final previous = json['previousBalance']?.toString() ?? '0';
    final paid = json['paidAmount']?.toString() ?? '0';
    final remaining = json['remainingAfter']?.toString() ?? '0';
    final due = json['amountDue']?.toString() ??
        ((double.tryParse(previous) ?? 0) + (double.tryParse(total) ?? 0))
            .toStringAsFixed(2);

    return Sale(
      id: json['id'] as int,
      deliveryGuyId: json['deliveryGuyId'] as int,
      shopId: json['shopId'] as int,
      saleDate: DateTime.parse(json['saleDate'] as String),
      totalAmount: total,
      previousBalance: previous,
      paidAmount: paid,
      remainingAfter: remaining,
      amountDue: due,
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

  Sale copyWith({
    String? paidAmount,
    String? remainingAfter,
    bool? billPrinted,
  }) {
    return Sale(
      id: id,
      deliveryGuyId: deliveryGuyId,
      shopId: shopId,
      saleDate: saleDate,
      totalAmount: totalAmount,
      previousBalance: previousBalance,
      paidAmount: paidAmount ?? this.paidAmount,
      remainingAfter: remainingAfter ?? this.remainingAfter,
      amountDue: amountDue,
      notes: notes,
      billPrinted: billPrinted ?? this.billPrinted,
      shopName: shopName,
      deliveryGuyName: deliveryGuyName,
      shopOwner: shopOwner,
      shopAddress: shopAddress,
      shopPhone: shopPhone,
      items: items,
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
  final double? paidAmount;
  final List<Map<String, int>> items;

  const SaleInput({
    required this.shopId,
    required this.saleDate,
    this.notes,
    this.paidAmount,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'shopId': shopId,
      'saleDate': saleDate,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      if (paidAmount != null) 'paidAmount': paidAmount,
      'items': items,
    };
  }
}
