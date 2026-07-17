import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/admin_models.dart';
import '../models/allocation.dart';
import '../models/app_features.dart';
import '../models/business_settings.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/shop.dart';
import '../models/shop_drop.dart';
import '../models/user.dart';
import '../models/notification.dart';
import '../utils/dates.dart';

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final String _baseUrl = AppConfig.apiBaseUrl;
  String? _token;
  void Function()? onAccountSuspended;
  AppFeatures features = AppFeatures.allEnabled;

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

  bool _isSuspendedPayload(Map<String, dynamic> data) {
    final code = data['code']?.toString();
    final error = data['error']?.toString();
    return code == 'ACCOUNT_SUSPENDED' || error == 'ACCOUNT_SUSPENDED';
  }

  Future<Map<String, dynamic>> _decode(http.Response response) async {
    final raw = response.body.isEmpty ? '{}' : response.body;
    final decoded = jsonDecode(raw);
    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{'error': 'Request failed'};

    if (response.statusCode >= 400) {
      if (_isSuspendedPayload(data)) {
        await clearToken();
        onAccountSuspended?.call();
        throw AccountSuspendedException();
      }
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
    final userMap = Map<String, dynamic>.from(
      data['user'] as Map<String, dynamic>,
    );
    userMap['phone'] ??= data['phone'];
    userMap['imageUrl'] ??= data['imageUrl'];
    return AppUser.fromJson(userMap);
  }

  Future<({AppUser user, String? phone, String? imageUrl})> getProfile() async {
    final me = await getMe();
    return (user: me, phone: me.phone, imageUrl: me.imageUrl);
  }

  Future<BusinessSettings> fetchBusinessSettings() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/settings/business'),
      headers: _headers(),
    );
    final data = await _decode(response);
    features = AppFeatures.fromJson(
      data['features'] is Map<String, dynamic>
          ? data['features'] as Map<String, dynamic>
          : null,
    );
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
    try {
      await _client.post(
        Uri.parse('$_baseUrl/api/auth/logout'),
        headers: _headers(),
      );
    } catch (_) {
      // Always clear local session.
    }
    await clearToken();
  }

  Future<String> uploadImage({
    required List<int> bytes,
    required String filename,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/api/upload'),
    );
    if (_token != null) {
      request.headers['Authorization'] = 'Bearer $_token';
    }

    final lower = filename.toLowerCase();
    final mime = lower.endsWith('.png')
        ? MediaType('image', 'png')
        : lower.endsWith('.webp')
            ? MediaType('image', 'webp')
            : MediaType('image', 'jpeg');

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: mime,
      ),
    );

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final data = await _decode(response);
    final url = data['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('Upload failed');
    }
    return url;
  }

  Future<AppUser> updateProfile({
    String? currentPassword,
    String? email,
    String? password,
    String? name,
    String? phone,
    String? imageUrl,
    bool clearImageUrl = false,
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
        if (clearImageUrl) 'imageUrl': null,
        if (!clearImageUrl && imageUrl != null) 'imageUrl': imageUrl,
      }),
    );

    final data = await _decode(response);
    final token = data['token'] as String;
    await saveToken(token);
    final userMap = Map<String, dynamic>.from(
      data['user'] as Map<String, dynamic>,
    );
    userMap['phone'] ??= data['phone'];
    userMap['imageUrl'] ??= data['imageUrl'];
    return AppUser.fromJson(userMap);
  }

  Future<List<AllocationSummary>> fetchMyAllocations({String? date}) async {
    final params = <String, String>{
      'date': date ?? localDateString(),
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
    int? deliveryGuyId,
  }) async {
    final params = <String, String>{};
    if (date != null) params['date'] = date;
    if (dateFrom != null) params['dateFrom'] = dateFrom;
    if (dateTo != null) params['dateTo'] = dateTo;
    if (deliveryGuyId != null) {
      params['deliveryGuyId'] = deliveryGuyId.toString();
    }

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

  Future<Sale> settleSalePayment(int saleId, double paidAmount) async {
    final response = await _client.patch(
      Uri.parse('$_baseUrl/api/sales/$saleId'),
      headers: _headers(),
      body: jsonEncode({'paidAmount': paidAmount}),
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
    String? historyDate,
    String? historyDateFrom,
    String? historyDateTo,
  }) async {
    final params = <String, String>{
      'date': date ?? localDateString(),
    };
    if (deliveryGuyId != null) {
      params['deliveryGuyId'] = deliveryGuyId.toString();
    }
    if (historyDate != null && historyDate.isNotEmpty) {
      params['historyDate'] = historyDate;
    }
    if (historyDateFrom != null && historyDateFrom.isNotEmpty) {
      params['historyDateFrom'] = historyDateFrom;
    }
    if (historyDateTo != null && historyDateTo.isNotEmpty) {
      params['historyDateTo'] = historyDateTo;
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

  Future<NotificationsPageResult> fetchNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/notifications').replace(
      queryParameters: {
        'page': page.toString(),
        'limit': limit.toString(),
      },
    );
    final response = await _client.get(uri, headers: _headers());
    final data = await _decode(response);
    return NotificationsPageResult.fromJson(data);
  }

  Future<void> markNotificationsRead({
    bool all = false,
    List<int>? ids,
  }) async {
    final response = await _client.patch(
      Uri.parse('$_baseUrl/api/notifications'),
      headers: _headers(),
      body: jsonEncode({
        if (all) 'all': true,
        if (ids != null) 'ids': ids,
      }),
    );
    await _decode(response);
  }

  Future<void> postLocation({
    required double latitude,
    required double longitude,
    double? accuracyMeters,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/locations'),
      headers: _headers(),
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
      }),
    );
    await _decode(response);
  }

  Future<void> stopLocationTracking() async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/api/locations'),
      headers: _headers(),
    );
    await _decode(response);
  }

  Future<List<Map<String, dynamic>>> fetchSaleComments(int saleId) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/sales/$saleId/comments'),
      headers: _headers(),
    );
    final data = await _decode(response);
    return ((data['comments'] as List?) ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> createSaleComment(
    int saleId, {
    required String body,
    int? parentId,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/sales/$saleId/comments'),
      headers: _headers(),
      body: jsonEncode({
        'body': body,
        if (parentId != null) 'parentId': parentId,
      }),
    );
    final data = await _decode(response);
    return ((data['comments'] as List?) ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> updateSaleComment(
    int commentId, {
    required String body,
  }) async {
    final response = await _client.patch(
      Uri.parse('$_baseUrl/api/comments/$commentId'),
      headers: _headers(),
      body: jsonEncode({'body': body}),
    );
    final data = await _decode(response);
    return ((data['comments'] as List?) ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> deleteSaleComment(int commentId) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/api/comments/$commentId'),
      headers: _headers(),
    );
    final data = await _decode(response);
    return ((data['comments'] as List?) ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> fetchConversations() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/conversations'),
      headers: _headers(),
    );
    return await _decode(response);
  }

  Future<void> pingPresence() async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/presence'),
      headers: _headers(),
    );
    await _decode(response);
  }

  Future<int> fetchChatUnreadCount() async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/api/conversations?unreadOnly=true'),
      headers: _headers(),
    );
    final data = await _decode(response);
    return (data['unreadCount'] as num?)?.toInt() ?? 0;
  }

  Future<({List<Map<String, dynamic>> messages, bool hasMore})>
      fetchChatMessages(
    int deliveryGuyId, {
    int? afterId,
    int? beforeId,
    int? limit,
  }) async {
    final uri = Uri.parse('$_baseUrl/api/conversations/$deliveryGuyId').replace(
      queryParameters: {
        if (afterId != null) 'afterId': afterId.toString(),
        if (beforeId != null) 'beforeId': beforeId.toString(),
        if (limit != null) 'limit': limit.toString(),
      },
    );
    final response = await _client.get(uri, headers: _headers());
    final data = await _decode(response);
    final messages = ((data['messages'] as List?) ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return (
      messages: messages,
      hasMore: data['hasMore'] == true,
    );
  }

  Future<Map<String, dynamic>> sendChatMessage(
    int deliveryGuyId, {
    String body = '',
    String? imageUrl,
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/api/conversations/$deliveryGuyId'),
      headers: _headers(),
      body: jsonEncode({
        'body': body,
        if (imageUrl != null) 'imageUrl': imageUrl,
      }),
    );
    final data = await _decode(response);
    return Map<String, dynamic>.from(data['message'] as Map);
  }

  Future<Map<String, dynamic>> updateChatMessage(
    int messageId, {
    required String body,
  }) async {
    final response = await _client.patch(
      Uri.parse('$_baseUrl/api/chat-messages/$messageId'),
      headers: _headers(),
      body: jsonEncode({'body': body}),
    );
    final data = await _decode(response);
    return Map<String, dynamic>.from(data['message'] as Map);
  }

  Future<Map<String, dynamic>?> deleteChatMessage(int messageId) async {
    final response = await _client.delete(
      Uri.parse('$_baseUrl/api/chat-messages/$messageId'),
      headers: _headers(),
    );
    final data = await _decode(response);
    final message = data['message'];
    if (message is Map) {
      return Map<String, dynamic>.from(message);
    }
    return null;
  }
}
