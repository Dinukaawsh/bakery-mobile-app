class Shop {
  final int id;
  final String name;
  final String ownerName;
  final String address;
  final String? phone;
  final String? route;
  final String outstandingBalance;
  final bool isActive;

  const Shop({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.address,
    required this.phone,
    required this.route,
    required this.outstandingBalance,
    required this.isActive,
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id'] as int,
      name: json['name'] as String,
      ownerName: json['ownerName'] as String,
      address: json['address'] as String,
      phone: json['phone'] as String?,
      route: json['route'] as String?,
      outstandingBalance: json['outstandingBalance']?.toString() ?? '0.00',
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  double get outstandingAsDouble =>
      double.tryParse(outstandingBalance) ?? 0;
}
