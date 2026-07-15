class AllocationRecord {
  final int id;
  final int deliveryGuyId;
  final String deliveryGuyName;
  final int productId;
  final String productName;
  final int quantity;
  final String allocationDate;

  const AllocationRecord({
    required this.id,
    required this.deliveryGuyId,
    required this.deliveryGuyName,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.allocationDate,
  });

  factory AllocationRecord.fromJson(Map<String, dynamic> json) {
    return AllocationRecord(
      id: json['id'] as int,
      deliveryGuyId: json['deliveryGuyId'] as int,
      deliveryGuyName: json['deliveryGuyName'] as String,
      productId: json['productId'] as int,
      productName: json['productName'] as String,
      quantity: json['quantity'] as int,
      allocationDate: json['allocationDate'] as String? ?? '',
    );
  }
}

class DeliveryPartner {
  final int id;
  final String email;
  final String name;
  final String? phone;
  final bool isActive;

  const DeliveryPartner({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    required this.isActive,
  });

  factory DeliveryPartner.fromJson(Map<String, dynamic> json) {
    return DeliveryPartner(
      id: json['id'] as int,
      email: json['email'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class DashboardStats {
  final int periodSalesCount;
  final String periodSalesTotal;
  final int totalProducts;
  final int totalDeliveryGuys;
  final int totalShops;

  const DashboardStats({
    required this.periodSalesCount,
    required this.periodSalesTotal,
    required this.totalProducts,
    required this.totalDeliveryGuys,
    required this.totalShops,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      periodSalesCount: json['periodSalesCount'] as int? ??
          json['todaySalesCount'] as int? ??
          0,
      periodSalesTotal: json['periodSalesTotal'] as String? ??
          json['todaySalesTotal'] as String? ??
          '0',
      totalProducts: json['totalProducts'] as int? ?? 0,
      totalDeliveryGuys: json['totalDeliveryGuys'] as int? ?? 0,
      totalShops: json['totalShops'] as int? ?? 0,
    );
  }
}
