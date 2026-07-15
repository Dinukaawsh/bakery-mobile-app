class AppUser {
  final int id;
  final String email;
  final String name;
  final String role;
  final String? phone;
  final String? imageUrl;

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.phone,
    this.imageUrl,
  });

  bool get isAdmin => role == 'admin';
  bool get isDelivery => role == 'delivery';

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      email: json['email'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      phone: json['phone'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  AppUser copyWith({
    String? email,
    String? name,
    String? phone,
    String? imageUrl,
    bool clearImageUrl = false,
  }) {
    return AppUser(
      id: id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role,
      phone: phone ?? this.phone,
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
    );
  }
}

class AccountSuspendedException implements Exception {
  @override
  String toString() => 'ACCOUNT_SUSPENDED';
}
