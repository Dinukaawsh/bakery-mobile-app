class Shop {
  final int id;
  final String name;
  final String ownerName;
  final String address;
  final String? phone;

  const Shop({
    required this.id,
    required this.name,
    required this.ownerName,
    required this.address,
    required this.phone,
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: json['id'] as int,
      name: json['name'] as String,
      ownerName: json['ownerName'] as String,
      address: json['address'] as String,
      phone: json['phone'] as String?,
    );
  }
}
