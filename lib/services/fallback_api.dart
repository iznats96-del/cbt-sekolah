import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';

/// Fallback HTTP client untuk API cadangan (Express + PostgreSQL di PC lokal)
/// Otomatis dipake kalau Supabase down / unreachable
class FallbackApi {
  static String get baseUrl => AppConfig.fallbackApiUrl;

  static String? _token;
  static Map<String, dynamic>? _user;

  static bool get isLoggedIn => _token != null && _user != null;
  static Map<String, dynamic>? get user => _user;
  static String? get role => _user?['role'] as String?;

  /// Login via fallback API
  static Future<bool> login(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/v1/token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _token = data['access_token'] as String?;
        _user = data['user'] as Map<String, dynamic>?;
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static void logout() {
    _token = null;
    _user = null;
  }

  /// GET request dengan auth header
  static Future<List<Map<String, dynamic>>> get(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final res = await http.get(uri, headers: _headers()).timeout(
      const Duration(seconds: 10),
    );
    if (res.statusCode != 200) throw Exception('GET $path: ${res.statusCode}');
    final decoded = jsonDecode(res.body);
    if (decoded is List) {
      return List<Map<String, dynamic>>.from(decoded);
    }
    return [Map<String, dynamic>.from(decoded)];
  }

  /// PATCH request
  static Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: {..._headers(), 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('PATCH $path: ${res.statusCode}');
    }
    return Map<String, dynamic>.from(jsonDecode(res.body));
  }

  /// POST request
  static Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: {..._headers(), 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('POST $path: ${res.statusCode}');
    }
    return jsonDecode(res.body);
  }

  /// Check apakah fallback API reachable
  static Future<bool> isReachable() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Map<String, String> _headers() {
    final h = <String, String>{};
    if (_token != null) h['Authorization'] = 'Bearer $_token';
    return h;
  }
}