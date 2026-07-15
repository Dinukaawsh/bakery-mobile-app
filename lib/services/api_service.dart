import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/admin_models.dart';
import '../models/allocation.dart';
import '../models/business_settings.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/shop.dart';
import '../models/shop_drop.dart';
import '../models/user.dart';

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final String _baseUrl = AppConfig.apiBaseUrl;
  String? _token;

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  Future<Map<String, dynamic>> _decode(http.Response response) async {
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(data['error'] ?? 'Request failed');
    }
    return data;
  }

  Future<AppUser> login(String email, String password) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/auth/login'),
      headers: _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = await _decode(response);
    final token = data['token'] as String;
    await saveToken(token);
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AppUser> getMe() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/auth/me'),
      headers: _headers(),
    );
    final data = await _decode(response);
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<({AppUser user, String? phone})> getProfile() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/auth/me'),
      headers: _headers(),
    );
    final data = await _decode(response);
    return (
      user: AppUser.fromJson(data['user'] as Map<String, dynamic>),
      phone: data['phone'] as String?,
    );
  }

  Future<BusinessSettings> fetchBusinessSettings() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/settings/business'),
      headers: _headers(),
    );
    final data = await _decode(response);
    return BusinessSettings.fromJson(
      data['settings'] as Map<String, dynamic>,
    );
  }

  Future<Sale> getSale(int saleId) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/sales/$saleId'),
      headers: _headers(),
    );
    final data = await _decode(response);
    return Sale.fromJson(data['sale'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    await _client.post(
      Uri.parse('$_baseUrl/api/auth/logout'),
      headers: _headers(),
    );
    await clearToken();
  }

  Future<AppUser> updateProfile({
    String? currentPassword,
    String? email,
    String? password,
    String? name,
    String? phone,
  }) async {
    final response = await _client.patch(
      Uri.parse('$_baseUrl/api/auth/profile'),
      headers: _headers(),
      body: jsonEncode({
        if (currentPassword != null) 'currentPassword': currentPassword,
        if (email != null) 'email': email,
        if (password != null) 'password': password,
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
      }),
    );

    final data = await _decode(response);
    final token = data['token'] as String;
    await saveToken(token);
    return AppUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<List<AllocationSummary>> fetchMyAllocations({String? date}) async {
    final params = <String, String>{
      'date': date ?? _localDateString(),
    };

    final uri = Uri.parse('$_baseUrl/api/allocations').replace(
      queryParameters: params,
    );
    final response = await _client.get(uri, headers: _headers());
    final data = await _decode(response);
    return (data['summary'] as List)
        .map((item) => AllocationSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Product>> fetchProducts() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/products'),
      headers: _headers(),
    );
    final data = await _decode(response);
    return (data['products'] as List)
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Shop>> fetchShops() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/shops'),
      headers: _headers(),
    );
    final data = await _decode(response);
    return (data['shops'] as List)
        .map((item) => Shop.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Shop> createShop({
    required String name,
    required String ownerName,
    required String address,
    String? phone,
    String? route,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/shops'),
      headers: _headers(),
      body: jsonEncode({
        'name': name,
        'ownerName': ownerName,
        'address': address,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (route != null && route.isNotEmpty) 'route': route,
      }),
    );
    final data = await _decode(response);
    return Shop.fromJson(data['shop'] as Map<String, dynamic>);
  }

  Future<List<ShopDropSummary>> fetchShopDrops({
    String? date,
    String? dateFrom,
    String? dateTo,
  }) async {
    final params = <String, String>{};
    if (date != null) params['date'] = date;
    if (dateFrom != null) params['dateFrom'] = dateFrom;
    if (dateTo != null) params['dateTo'] = dateTo;

    final uri = Uri.parse('$_baseUrl/api/shops/drops').replace(
      queryParameters: params.isEmpty ? null : params,
    );
    final response = await _client.get(uri, headers: _headers());
    final data = await _decode(response);
    return (data['drops'] as List)
        .map((item) => ShopDropSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Sale>> fetchSales({
    bool today = false,
    String? dateFrom,
    String? dateTo,
    int? deliveryGuyId,
  }) async {
    final params = <String, String>{};
    if (today) params['today'] = 'true';
    if (dateFrom != null) params['dateFrom'] = dateFrom;
    if (dateTo != null) params['dateTo'] = dateTo;
    if (deliveryGuyId != null) {
      params['deliveryGuyId'] = deliveryGuyId.toString();
    }

    final uri = Uri.parse('$_baseUrl/api/sales').replace(queryParameters: params);
    final response = await _client.get(uri, headers: _headers());
    final data = await _decode(response);
    return (data['sales'] as List)
        .map((item) => Sale.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Sale> createSale(SaleInput input) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/sales'),
      headers: _headers(),
      body: jsonEncode(input.toJson()),
    );
    final data = await _decode(response);
    return Sale.fromJson(data['sale'] as Map<String, dynamic>);
  }

  Future<Sale> markBillPrinted(int saleId) async {
    final response = await _client.patch(
      Uri.parse('$_baseUrl/api/sales/$saleId'),
      headers: _headers(),
      body: jsonEncode({'billPrinted': true}),
    );
    final data = await _decode(response);
    return Sale.fromJson(data['sale'] as Map<String, dynamic>);
  }

  Future<DashboardStats> fetchDashboard() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/dashboard'),
      headers: _headers(),
    );
    final data = await _decode(response);
    return DashboardStats.fromJson(data['stats'] as Map<String, dynamic>);
  }

  Future<List<DeliveryPartner>> fetchDeliveryPartners() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/delivery-guys'),
      headers: _headers(),
    );
    final data = await _decode(response);
    return (data['deliveryGuys'] as List)
        .map((item) => DeliveryPartner.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<({
    List<AllocationSummary> summary,
    List<AllocationRecord> records,
  })> fetchAdminAllocations({
    String? date,
    int? deliveryGuyId,
  }) async {
    final params = <String, String>{
      'date': date ?? _localDateString(),
    };
    if (deliveryGuyId != null) {
      params['deliveryGuyId'] = deliveryGuyId.toString();
    }

    final uri = Uri.parse('$_baseUrl/api/allocations').replace(
      queryParameters: params,
    );
    final response = await _client.get(uri, headers: _headers());
    final data = await _decode(response);
    final summary = (data['summary'] as List)
        .map((item) => AllocationSummary.fromJson(item as Map<String, dynamic>))
        .toList();
    final records = (data['allocations'] as List? ?? [])
        .map((item) => AllocationRecord.fromJson(item as Map<String, dynamic>))
        .toList();
    return (summary: summary, records: records);
  }

  Future<void> createStockAssignment({
    required int deliveryGuyId,
    required String allocationDate,
    required List<Map<String, int>> items,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/allocations'),
      headers: _headers(),
      body: jsonEncode({
        'deliveryGuyId': deliveryGuyId,
        'allocationDate': allocationDate,
        'items': items,
      }),
    );
    await _decode(response);
  }

  String _localDateString() {
    final now = DateTime.now().toLocal();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }
}
