import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config.dart';

/// Hybrid API client: Supabase sebagai PRIMARY, Express+PostgreSQL di PC sebagai FALLBACK.
/// Semua method mencoba Supabase dulu; jika gagal (network/timeout/5xx) otomatis fallback.
class HybridApi {
  static SupabaseClient get _supa => Supabase.instance.client;
  static String get _fallback => AppConfig.fallbackApiUrl;

  static bool _fallbackActive = false;
  static String? _fallbackToken;
  static Map<String, dynamic>? _fallbackUser;

  /// Cek apakah sedang dalam mode fallback
  static bool get isUsingFallback => _fallbackActive;

  /// Token hasil login fallback (dipakai Api untuk header HTTP fallback).
  static String? get fallbackToken => _fallbackToken;

  // ─── AUTH ───────────────────────────────────────────────

  /// Login: coba Supabase dulu, fallback ke local API
  /// Kalau Supabase dimatiin (PRIMARY_FALLBACK=true), SDK diarahkan ke server
  /// cadangan (config.dart) sehingga login lewat SDK tetap aman dan session-nya
  /// tersimpan di SDK — semua panggilan Api.client.from(...) jadi ikut memakai
  /// token fallback.
  static Future<Map<String, dynamic>> login(String email, String password) async {
    if (AppConfig.supabaseDisabled) {
      // SDK -> server fallback: login via SDK supaya session + refresh token
      // tersimpan (dibutuhkan oleh 34 call Api.client.from(...)).
      try {
        final res = await _supa.auth.signInWithPassword(
          email: email,
          password: password,
        ).timeout(const Duration(seconds: 8));
        if (res.user != null) {
          _fallbackActive = true;
          _fallbackToken = res.session?.accessToken;
          _fallbackUser = <String, dynamic>{
            'id': res.user!.id,
            'email': res.user!.email,
            'role': (res.user!.userMetadata?['role'] ?? res.user!.appMetadata?['role'] ?? ''),
          };
          debugPrint('HybridApi: Fallback login SUCCESS (via SDK)');
          return {'source': 'fallback', 'user': _fallbackUser};
        }
      } catch (e) {
        debugPrint('HybridApi: SDK->fallback login failed ($e), trying raw HTTP...');
      }
      return await _fallbackLogin(email, password);
    }
    try {
      final res = await _supa.auth.signInWithPassword(
        email: email,
        password: password,
      ).timeout(const Duration(seconds: 8));

      if (res.user != null) {
        _fallbackActive = false;
        return {'source': 'supabase', 'user': res.user};
      }
      throw Exception('Supabase login returned null user');
    } catch (e) {
      if (!AppConfig.failoverEnabled) rethrow; // Supabase-only mode
      debugPrint('HybridApi: Supabase login failed ($e), trying fallback...');
      return await _fallbackLogin(email, password);
    }
  }

  static Future<Map<String, dynamic>> _fallbackLogin(String email, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$_fallback/auth/v1/token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        _fallbackToken = data['access_token'] as String?;
        _fallbackUser = data['user'] as Map<String, dynamic>?;
        _fallbackActive = true;
        debugPrint('HybridApi: Fallback login SUCCESS');
        return {'source': 'fallback', 'user': _fallbackUser};
      }
      throw Exception('Fallback login HTTP ${res.statusCode}');
    } catch (e) {
      _fallbackActive = false;
      rethrow;
    }
  }

  static Future<void> logout() async {
    _fallbackToken = null;
    _fallbackUser = null;
    _fallbackActive = false;
    try {
      await _supa.auth.signOut();
    } catch (_) {}
  }

  // ─── RPC CALLS (primary path for siswa) ─────────────────

  /// RPC call dengan auto-fallback
  static Future<dynamic> rpc(String function, {Map<String, dynamic>? params}) async {
    if (!_fallbackActive) {
      try {
        final result = await _supa.rpc(function, params: params ?? {}).timeout(
          const Duration(seconds: 10),
        );
        return result;
      } catch (e) {
        if (!AppConfig.failoverEnabled) rethrow; // Supabase-only mode
        debugPrint('HybridApi: RPC $function failed on Supabase ($e), switching to fallback');
        _fallbackActive = true;
      }
    }
    // Fallback path
    return await _fallbackRpc(function, params: params);
  }

  static Future<dynamic> _fallbackRpc(String function, {Map<String, dynamic>? params}) async {
    final res = await http.post(
      Uri.parse('$_fallback/rest/v1/rpc/$function'),
      headers: {
        'Content-Type': 'application/json',
        if (_fallbackToken != null) 'Authorization': 'Bearer $_fallbackToken',
      },
      body: jsonEncode(params ?? {}),
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) throw Exception('Fallback RPC $function: HTTP ${res.statusCode}');
    return jsonDecode(res.body);
  }

  // ─── TABLE QUERIES (select / insert / update / delete) ──

  /// SELECT dengan auto-fallback
  static Future<List<Map<String, dynamic>>> select(
    String table, {
    String? columns,
    Map<String, String>? eq,
    int? limit,
    String? order,
    bool ascending = true,
  }) async {
    if (!_fallbackActive) {
      try {
        dynamic q = _supa.from(table).select(columns ?? '*');
        if (eq != null) {
          for (final entry in eq.entries) {
            q = q.eq(entry.key, entry.value);
          }
        }
        if (order != null) q = q.order(order, ascending: ascending);
        if (limit != null) q = q.limit(limit);

        final rows = await q.timeout(const Duration(seconds: 10));
        return List<Map<String, dynamic>>.from(rows);
      } catch (e) {
        if (!AppConfig.failoverEnabled) rethrow; // Supabase-only mode
        debugPrint('HybridApi: SELECT $table failed on Supabase ($e), switching to fallback');
        _fallbackActive = true;
      }
    }
    return await _fallbackSelect(table, columns: columns, eq: eq, limit: limit, order: order);
  }

  static Future<List<Map<String, dynamic>>> _fallbackSelect(
    String table, {
    String? columns,
    Map<String, String>? eq,
    int? limit,
    String? order,
  }) async {
    final queryParams = <String, String>{
      if (columns != null) 'select': columns,
      if (limit != null) 'limit': limit.toString(),
      if (order != null) 'order': order,
      if (eq != null) ...eq.map((k, v) => MapEntry(k, 'eq.$v')),
    };

    final uri = Uri.parse('$_fallback/rest/v1/$table').replace(queryParameters: queryParams);
    final res = await http.get(uri, headers: _fallbackHeaders()).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) throw Exception('Fallback SELECT $table: HTTP ${res.statusCode}');
    final decoded = jsonDecode(res.body);
    if (decoded is List) return List<Map<String, dynamic>>.from(decoded);
    return [Map<String, dynamic>.from(decoded)];
  }

  /// INSERT dengan auto-fallback
  static Future<Map<String, dynamic>> insert(String table, Map<String, dynamic> data) async {
    if (!_fallbackActive) {
      try {
        final rows = await _supa.from(table).insert(data).select().timeout(const Duration(seconds: 10));
        return Map<String, dynamic>.from(rows.first);
      } catch (e) {
        if (!AppConfig.failoverEnabled) rethrow; // Supabase-only mode
        debugPrint('HybridApi: INSERT $table failed on Supabase ($e), switching to fallback');
        _fallbackActive = true;
      }
    }
    return await _fallbackInsert(table, data);
  }

  static Future<Map<String, dynamic>> _fallbackInsert(String table, Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$_fallback/rest/v1/$table'),
      headers: {..._fallbackHeaders(), 'Content-Type': 'application/json', 'Prefer': 'return=representation'},
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Fallback INSERT $table: HTTP ${res.statusCode}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is List && decoded.isNotEmpty) return Map<String, dynamic>.from(decoded.first);
    return Map<String, dynamic>.from(decoded);
  }

  /// UPDATE dengan auto-fallback
  static Future<void> update(String table, String id, Map<String, dynamic> data) async {
    if (!_fallbackActive) {
      try {
        await _supa.from(table).update(data).eq('id', id).timeout(const Duration(seconds: 10));
        return;
      } catch (e) {
        if (!AppConfig.failoverEnabled) rethrow; // Supabase-only mode
        debugPrint('HybridApi: UPDATE $table failed on Supabase ($e), switching to fallback');
        _fallbackActive = true;
      }
    }
    await _fallbackUpdate(table, id, data);
  }

  static Future<void> _fallbackUpdate(String table, String id, Map<String, dynamic> data) async {
    final res = await http.patch(
      Uri.parse('$_fallback/rest/v1/$table'),
      headers: {..._fallbackHeaders(), 'Content-Type': 'application/json'},
      body: jsonEncode({...data, 'id': id}),
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) throw Exception('Fallback UPDATE $table: HTTP ${res.statusCode}');
  }

  /// DELETE dengan auto-fallback
  static Future<void> delete(String table, String id) async {
    if (!_fallbackActive) {
      try {
        await _supa.from(table).delete().eq('id', id).timeout(const Duration(seconds: 10));
        return;
      } catch (e) {
        if (!AppConfig.failoverEnabled) rethrow; // Supabase-only mode
        debugPrint('HybridApi: DELETE $table failed on Supabase ($e), switching to fallback');
        _fallbackActive = true;
      }
    }
    await _fallbackDelete(table, id);
  }

  static Future<void> _fallbackDelete(String table, String id) async {
    final res = await http.delete(
      Uri.parse('$_fallback/rest/v1/$table?id=eq.$id'),
      headers: _fallbackHeaders(),
    ).timeout(const Duration(seconds: 10));

    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Fallback DELETE $table: HTTP ${res.statusCode}');
    }
  }

  // ─── HEALTH CHECK ───────────────────────────────────────

  /// Cek status kedua backend
  static Future<Map<String, bool>> healthCheck() async {
    bool supaOk = false;
    bool fallbackOk = false;

    try {
      await _supa.from('profiles').select('id').limit(1).timeout(const Duration(seconds: 5));
      supaOk = true;
    } catch (_) {}

    try {
      final res = await http.get(Uri.parse('$_fallback/health')).timeout(const Duration(seconds: 3));
      fallbackOk = res.statusCode == 200;
    } catch (_) {}

    return {'supabase': supaOk, 'fallback': fallbackOk};
  }

  // ─── HELPERS ────────────────────────────────────────────

  static Map<String, String> _fallbackHeaders() {
    final h = <String, String>{};
    if (_fallbackToken != null) h['Authorization'] = 'Bearer $_fallbackToken';
    return h;
  }
}