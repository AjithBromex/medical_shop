import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiService {
  static final ApiService instance = ApiService._();
  ApiService._();

  // Change this if running on a remote server or emulator (e.g. 10.0.2.2 for Android emulator)
  String baseUrl = 'http://localhost:5000/api';

  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  // ------------------------------------------------------------- Health
  Future<bool> checkHealth() async {
    try {
      final res = await http.get(Uri.parse('${baseUrl.replaceAll('/api', '')}/health'));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------- Medical Shops
  Future<List<MedicalShop>> shops() async {
    final res = await http.get(Uri.parse('$baseUrl/shops'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to load shops: ${res.body}');
    final list = jsonDecode(res.body) as List;
    return list.map((m) {
      final map = m as Map<String, dynamic>;
      return MedicalShop(
        id: map['_id'] != null ? map['_id'].hashCode : map['id'] as int?,
        name: map['name'] as String,
        notes: map['notes'] as String?,
        phone: map['phone'] as String?,
        address: map['address'] as String?,
        isActive: map['active'] as bool? ?? true,
      );
    }).toList();
  }

  Future<void> saveShop(MedicalShop shop) async {
    if (shop.id != null) {
      // update
      final res = await http.put(
        Uri.parse('$baseUrl/shops/${shop.id}'),
        headers: _headers,
        body: jsonEncode({
          'name': shop.name,
          'notes': shop.notes,
          'phone': shop.phone,
          'address': shop.address,
          'active': shop.isActive,
        }),
      );
      if (res.statusCode != 200) throw Exception('Failed to update shop: ${res.body}');
    } else {
      // create
      final res = await http.post(
        Uri.parse('$baseUrl/shops'),
        headers: _headers,
        body: jsonEncode({
          'name': shop.name,
          'notes': shop.notes,
          'phone': shop.phone,
          'address': shop.address,
          'active': shop.isActive,
        }),
      );
      if (res.statusCode != 201) throw Exception('Failed to create shop: ${res.body}');
    }
  }

  Future<void> deleteShop(String shopId) async {
    final res = await http.delete(Uri.parse('$baseUrl/shops/$shopId'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to delete shop: ${res.body}');
  }

  // ------------------------------------------------------------- Collections
  Future<Map<String, dynamic>> collections({
    String? q,
    DateTime? dateFrom,
    DateTime? dateTo,
    int? shopId,
    String? method,
    int page = 1,
    int limit = 50,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (q != null && q.isNotEmpty) params['q'] = q;
    if (dateFrom != null) params['dateFrom'] = dateFrom.toIso8601String();
    if (dateTo != null) params['dateTo'] = dateTo.toIso8601String();
    if (shopId != null) params['shopId'] = shopId.toString();
    if (method != null) params['method'] = method;

    final uri = Uri.parse('$baseUrl/collections').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to load collections: ${res.body}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> createCollection({
    required String shopId,
    required String shopName,
    required DateTime date,
    required int cash,
    required int gpay,
    required int cheque,
    String? receiptNumber,
    String? notes,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/collections'),
      headers: _headers,
      body: jsonEncode({
        if (receiptNumber != null && receiptNumber.isNotEmpty) 'receiptNumber': receiptNumber,
        'shopId': shopId,
        'shopName': shopName,
        'date': date.toIso8601String(),
        'cash': cash,
        'gpay': gpay,
        'cheque': cheque,
        if (notes != null) 'notes': notes,
      }),
    );
    if (res.statusCode != 201) throw Exception('Failed to create collection: ${res.body}');
  }

  // ------------------------------------------------------------- Expenses
  Future<Map<String, dynamic>> expenses({
    String? q,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? category,
    int page = 1,
    int limit = 50,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (q != null && q.isNotEmpty) params['q'] = q;
    if (dateFrom != null) params['dateFrom'] = dateFrom.toIso8601String();
    if (dateTo != null) params['dateTo'] = dateTo.toIso8601String();
    if (category != null) params['category'] = category;

    final uri = Uri.parse('$baseUrl/expenses').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to load expenses: ${res.body}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> createExpense({
    required DateTime date,
    required String category,
    required String description,
    required int amount,
    String? notes,
    String? displayId,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/expenses'),
      headers: _headers,
      body: jsonEncode({
        if (displayId != null) 'displayId': displayId,
        'date': date.toIso8601String(),
        'category': category,
        'description': description,
        'amount': amount,
        if (notes != null) 'notes': notes,
      }),
    );
    if (res.statusCode != 201) throw Exception('Failed to create expense: ${res.body}');
  }

  Future<List<String>> categories() async {
    final res = await http.get(Uri.parse('$baseUrl/expenses/categories'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to load categories: ${res.body}');
    final list = jsonDecode(res.body) as List;
    return list.map((e) => e.toString()).toList();
  }

  // ------------------------------------------------------------- Reports & Dashboard
  Future<Map<String, dynamic>> dashboard() async {
    final res = await http.get(Uri.parse('$baseUrl/reports/dashboard'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to load dashboard: ${res.body}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> dailyMoney({DateTime? from, DateTime? to}) async {
    final params = <String, String>{};
    if (from != null) params['from'] = from.toIso8601String();
    if (to != null) params['to'] = to.toIso8601String();
    final uri = Uri.parse('$baseUrl/reports/daily-money').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to load daily money: ${res.body}');
    return jsonDecode(res.body) as List;
  }
}
