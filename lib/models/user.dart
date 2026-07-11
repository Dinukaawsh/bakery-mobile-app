class AppUser {
  final int id;
  final String email;
  final String name;
  final String role;

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
  });

  bool get isAdmin => role == 'admin';
  bool get isDelivery => role == 'delivery';

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      email: json['email'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
    );
  }
}
