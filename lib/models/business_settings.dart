class BusinessSettings {
  final String businessName;
  final String address;
  final String phone;
  final String? email;
  final String? ownerName;

  const BusinessSettings({
    required this.businessName,
    required this.address,
    required this.phone,
    this.email,
    this.ownerName,
  });

  factory BusinessSettings.fromJson(Map<String, dynamic> json) {
    return BusinessSettings(
      businessName: json['businessName'] as String? ?? 'Bakery',
      address: json['address'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      ownerName: json['ownerName'] as String?,
    );
  }

  static const fallback = BusinessSettings(
    businessName: 'Bakery',
    address: '',
    phone: '',
  );
}
