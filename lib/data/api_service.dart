import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'models.dart';

import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService instance = ApiService._();
  ApiService._();

  static const String defaultHostedUrl = 'https://medical-shop-api.onrender.com/api';

  static String get defaultBaseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:5000/api';
    }
    return 'http://localhost:5000/api';
  }

  static String get defaultApiKey {
    const envKey = String.fromEnvironment('API_KEY');
    return envKey;
  }

  String _baseUrl = defaultBaseUrl;
  String _apiKey = defaultApiKey;
  bool _initialized = false;

  String get baseUrl => _baseUrl;
  String get apiKey => _apiKey;

  static String normalizeBaseUrl(String url) {
    var trimmed = url.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (trimmed.isEmpty) return defaultBaseUrl;
    if (!trimmed.endsWith('/api')) {
      trimmed = '$trimmed/api';
    }
    return trimmed;
  }

  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('server_api_url');
      if (savedUrl != null && savedUrl.trim().isNotEmpty) {
        _baseUrl = normalizeBaseUrl(savedUrl);
      }
      final savedKey = prefs.getString('server_api_key');
      if (savedKey != null && savedKey.trim().isNotEmpty) {
        _apiKey = savedKey.trim();
      }
    } catch (_) {}
    _initialized = true;
  }

  Future<void> updateConfig({required String newUrl, String? newApiKey}) async {
    _baseUrl = normalizeBaseUrl(newUrl);
    if (newApiKey != null) _apiKey = newApiKey.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_api_url', _baseUrl);
    await prefs.setString('server_api_key', _apiKey);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_apiKey.isNotEmpty) 'x-api-key': _apiKey,
      };

  // ------------------------------------------------------------- Health
  Future<bool> checkHealth() async {
    try {
      final healthUri = Uri.parse(_baseUrl.replaceAll(RegExp(r'/api/?$'), '') + '/health');
      final res = await http.get(healthUri).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ------------------------------------------------------------- Sync
  Future<Map<String, dynamic>?> getAllSyncData() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/sync/all'), headers: _headers).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[ApiService] getAllSyncData error: $e');
      return null;
    }
  }

  Future<bool> pushSyncBatch({
    List<Map<String, dynamic>> shops = const [],
    List<Map<String, dynamic>> collections = const [],
    List<Map<String, dynamic>> expenses = const [],
    List<String> categories = const [],
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/sync/push'),
            headers: _headers,
            body: jsonEncode({
              'shops': shops,
              'collections': collections,
              'expenses': expenses,
              'categories': categories,
            }),
          )
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[ApiService] pushSyncBatch error: $e');
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
    final res = await http.post(
      Uri.parse('$baseUrl/shops'),
      headers: _headers,
      body: jsonEncode({
        'name': shop.name.trim(),
        'notes': shop.notes ?? '',
        'phone': shop.phone ?? '',
        'address': shop.address ?? '',
        'active': shop.isActive,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to save shop to Atlas: ${res.body}');
    }
  }

  Future<void> deleteShopByName(String name) async {
    final encoded = Uri.encodeComponent(name.trim());
    final res = await http.delete(Uri.parse('$baseUrl/shops/by-name/$encoded'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to delete shop from Atlas: ${res.body}');
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
    bool all = false,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (all) 'all': 'true',
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

  Future<void> createOrUpdateCollection({
    required String receiptNumber,
    required String shopName,
    dynamic shopId,
    required DateTime date,
    required int cash,
    required int gpay,
    required int cheque,
    String? notes,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/collections'),
      headers: _headers,
      body: jsonEncode({
        'receiptNumber': receiptNumber.trim(),
        if (shopId != null) 'shopId': shopId,
        'shopName': shopName.trim(),
        'date': date.toIso8601String(),
        'cash': cash,
        'gpay': gpay,
        'cheque': cheque,
        'notes': notes ?? '',
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to save collection to Atlas: ${res.body}');
    }
  }

  Future<void> deleteCollectionByReceipt(String receiptNumber) async {
    final encoded = Uri.encodeComponent(receiptNumber.trim());
    final res = await http.delete(Uri.parse('$baseUrl/collections/by-receipt/$encoded'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to delete collection from Atlas: ${res.body}');
  }

  // ------------------------------------------------------------- Expenses
  Future<Map<String, dynamic>> expenses({
    String? q,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? category,
    int page = 1,
    int limit = 50,
    bool all = false,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (all) 'all': 'true',
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

  Future<void> createOrUpdateExpense({
    required String displayId,
    required DateTime date,
    required String category,
    required String description,
    required int amount,
    String? notes,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/expenses'),
      headers: _headers,
      body: jsonEncode({
        'displayId': displayId.trim(),
        'date': date.toIso8601String(),
        'category': category.trim(),
        'description': description,
        'amount': amount,
        'notes': notes ?? '',
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to save expense to Atlas: ${res.body}');
    }
  }

  Future<void> deleteExpenseByDisplayId(String displayId) async {
    final encoded = Uri.encodeComponent(displayId.trim());
    final res = await http.delete(Uri.parse('$baseUrl/expenses/by-display-id/$encoded'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to delete expense from Atlas: ${res.body}');
  }

  Future<List<String>> categories() async {
    final res = await http.get(Uri.parse('$baseUrl/expenses/categories'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to load categories: ${res.body}');
    final list = jsonDecode(res.body) as List;
    return list.map((e) => e.toString()).toList();
  }

  Future<void> addCategory(String name) async {
    final res = await http.post(
      Uri.parse('$baseUrl/expenses/categories'),
      headers: _headers,
      body: jsonEncode({'name': name.trim()}),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to add category: ${res.body}');
    }
  }

  Future<void> deleteCategory(String name) async {
    final encoded = Uri.encodeComponent(name.trim());
    final res = await http.delete(Uri.parse('$baseUrl/expenses/categories/$encoded'), headers: _headers);
    if (res.statusCode != 200) throw Exception('Failed to delete category: ${res.body}');
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
