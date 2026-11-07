import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config.dart';

/// BackendRouter: Active-Passive Automatic Failover
///
/// PRIMARY: Supabase Cloud (via supabase_flutter SDK)
/// FALLBACK: Node.js + PostgreSQL via Cloudflare Tunnel (smkyp79.my.id)
///
/// Features:
/// - Circuit breaker with configurable failure threshold
/// - Periodic health check probe on recovery interval
/// - Exponential backoff retry on transient errors
/// - Distinguishes auth/validation errors `(4xx)` from server/network errors `(5xx/timeout)`
/// - Logs every server switch for admin monitoring
/// - Drop-in replacement: same static Api interface + `Crud<T>` helper
class Api {
  // ─── SUPABASE CLIENT ──────────────────────────────────────
  static SupabaseClient get client => Supabase.instance.client;
  static User? get user => client.auth.currentUser;

  // ─── ROLE CACHE ───────────────────────────────────────────
  static String? _cachedRole;
  static String? get role => _cachedRole;
  static void setRole(String? r) => _cachedRole = r;

  static Future<Map<String, dynamic>?> currentProfile() async {
    final u = user;
    if (u == null) return null;
    final rows = await routerSelect('profiles', eq: {'id': u.id}, limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  static Future<bool> init() async {
    final u = user;
    if (u == null) return false;
    final p = await currentProfile();
    _cachedRole = p?['role'] as String?;
    return _cachedRole != null;
  }

  // ─── CIRCUIT BREAKER STATE ────────────────────────────────
  static int _consecutiveFailures = 0;
  static bool _circuitOpen = false;
  static DateTime? _circuitOpenedAt;
  static Timer? _healthCheckTimer;

  /// true when requests are currently routed to fallback
  static bool get isUsingFallback => _circuitOpen;

  /// Start periodic health check probe (call once in main.dart after init)
  static void startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(
      Duration(seconds: AppConfig.healthCheckIntervalSec),
      (_) => _probePrimary(),
    );
  }

  static void stopHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  /// Probe Supabase health; if healthy, close circuit breaker
  static Future<void> _probePrimary() async {
    if (!_circuitOpen) return;

    final elapsed =
        DateTime.now().difference(_circuitOpenedAt ?? DateTime.now());
    if (elapsed.inSeconds < AppConfig.circuitBreakerOpenSec) return;

    try {
      await client
          .from('profiles')
          .select('id')
          .limit(1)
          .timeout(Duration(seconds: AppConfig.requestTimeoutSec));
      debugPrint(
          '[BackendRouter] ✅ Supabase recovered — switching back to PRIMARY');
      _circuitOpen = false;
      _consecutiveFailures = 0;
      _circuitOpenedAt = null;
    } catch (_) {
      debugPrint(
          '[BackendRouter] ⏳ Supabase still down — staying on FALLBACK');
    }
  }

  /// Record a transient failure; open circuit if threshold reached
  static void _recordFailure(String context) {
    _consecutiveFailures++;
    if (_consecutiveFailures >= AppConfig.failureThreshold && !_circuitOpen) {
      _circuitOpen = true;
      _circuitOpenedAt = DateTime.now();
      debugPrint(
        '[BackendRouter] 🔴 Circuit OPEN after $_consecutiveFailures failures ($context) '
        '— switching to FALLBACK (${AppConfig.fallbackApiUrl})',
      );
    }
  }

  /// Reset failure counter on successful primary request
  static void _recordSuccess() {
    if (_consecutiveFailures > 0) {
      debugPrint('[BackendRouter] 🟢 Primary success — reset failure counter');
    }
    _consecutiveFailures = 0;
  }

  /// Determine if error is transient (network/timeout/5xx) vs permanent (4xx)
  static bool _isTransientError(Object error) {
    if (error is TimeoutException) return true;
    if (error is SocketException) return true;
    if (error is http.ClientException) return true;
    if (error is PostgrestException) {
      // PostgrestException.code is a String like "PGRST116" or numeric "500"
      final code = error.code;
      if (code != null) {
        final parsed = int.tryParse(code);
        if (parsed != null && parsed >= 500) return true;
      }
      final msg = error.message.toLowerCase();
      if (msg.contains('connection') ||
          msg.contains('timeout') ||
          msg.contains('network') ||
          msg.contains('unreachable')) {
        return true;
      }
      return false;
    }
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('network') ||
          msg.contains('timeout') ||
          msg.contains('connection')) {
        return true;
      }
      return false;
    }
    return false;
  }

  // ─── FALLBACK HTTP HELPERS ────────────────────────────────
  static String? _fallbackToken;

  static Map<String, String> _fallbackHeaders({String? contentType}) {
    final h = <String, String>{};
    if (_fallbackToken != null) h['Authorization'] = 'Bearer $_fallbackToken';
    if (contentType != null) h['Content-Type'] = contentType;
    return h;
  }

  static Future<List<Map<String, dynamic>>> _fallbackGet(
    String table, {
    String? select,
    Map<String, String>? eq,
    String? order,
    bool ascending = true,
    int? limit,
  }) async {
    final params = <String, String>{};
    if (select != null) params['select'] = select;
    if (order != null) {
      params['order'] = '$order.${ascending ? "asc" : "desc"}';
    }
    if (limit != null) params['limit'] = limit.toString();
    if (eq != null) {
      eq.forEach((k, v) => params[k] = 'eq.$v');
    }
    final uri = Uri.parse('${AppConfig.fallbackApiUrl}/rest/v1/$table')
        .replace(queryParameters: params.isNotEmpty ? params : null);
    final res = await http
        .get(uri, headers: _fallbackHeaders())
        .timeout(Duration(seconds: AppConfig.requestTimeoutSec));
    if (res.statusCode != 200) {
      throw Exception('Fallback GET $table: ${res.statusCode}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is List) return List<Map<String, dynamic>>.from(decoded);
    return [Map<String, dynamic>.from(decoded)];
  }

  static Future<Map<String, dynamic>> _fallbackInsert(
    String table,
    Map<String, dynamic> data,
  ) async {
    final res = await http
        .post(
          Uri.parse('${AppConfig.fallbackApiUrl}/rest/v1/$table'),
          headers: _fallbackHeaders(contentType: 'application/json'),
          body: jsonEncode(data),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeoutSec));
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Fallback INSERT $table: ${res.statusCode}');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is List && decoded.isNotEmpty) {
      return Map<String, dynamic>.from(decoded.first);
    }
    return Map<String, dynamic>.from(decoded);
  }

  static Future<void> _fallbackUpdate(
    String table,
    String id,
    Map<String, dynamic> data,
  ) async {
    final res = await http
        .patch(
          Uri.parse('${AppConfig.fallbackApiUrl}/rest/v1/$table'),
          headers: _fallbackHeaders(contentType: 'application/json'),
          body: jsonEncode({...data, 'id': id}),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeoutSec));
    if (res.statusCode != 200) {
      throw Exception('Fallback UPDATE $table: ${res.statusCode}');
    }
  }

  static Future<void> _fallbackDelete(String table, String id) async {
    final res = await http
        .delete(
          Uri.parse('${AppConfig.fallbackApiUrl}/rest/v1/$table?id=eq.$id'),
          headers: _fallbackHeaders(),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeoutSec));
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception('Fallback DELETE $table: ${res.statusCode}');
    }
  }

  static Future<dynamic> _fallbackRpc(
    String function,
    Map<String, dynamic> params,
  ) async {
    final res = await http
        .post(
          Uri.parse('${AppConfig.fallbackApiUrl}/rest/v1/rpc/$function'),
          headers: _fallbackHeaders(contentType: 'application/json'),
          body: jsonEncode(params),
        )
        .timeout(Duration(seconds: AppConfig.requestTimeoutSec));
    if (res.statusCode != 200) {
      throw Exception('Fallback RPC $function: ${res.statusCode}');
    }
    return jsonDecode(res.body);
  }

  // ─── FAILOVER-AWARE CRUD OPERATIONS ───────────────────────

  /// SELECT with automatic failover + exponential backoff retry
  static Future<List<Map<String, dynamic>>> routerSelect(
    String table, {
    String? select,
    Map<String, String>? eq,
    String? order,
    bool ascending = true,
    int? limit,
  }) async {
    if (_circuitOpen) {
      return await _fallbackGet(table,
          select: select,
          eq: eq,
          order: order,
          ascending: ascending,
          limit: limit);
    }

    for (int attempt = 0; attempt <= AppConfig.maxRetries; attempt++) {
      try {
        dynamic q = client.from(table).select(select ?? '*');
        if (eq != null) {
          for (final entry in eq.entries) {
            q = q.eq(entry.key, entry.value);
          }
        }
        if (order != null) q = q.order(order, ascending: ascending);
        if (limit != null) q = q.limit(limit);

        final rows =
            await q.timeout(Duration(seconds: AppConfig.requestTimeoutSec));
        _recordSuccess();
        return List<Map<String, dynamic>>.from(rows);
      } catch (e) {
        if (!_isTransientError(e)) rethrow;
        if (attempt < AppConfig.maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          continue;
        }
        _recordFailure('SELECT $table');
        debugPrint(
            '[BackendRouter] ↪️ Fallback SELECT $table after primary failure');
        return await _fallbackGet(table,
            select: select,
            eq: eq,
            order: order,
            ascending: ascending,
            limit: limit);
      }
    }
    throw Exception('Unreachable');
  }

  /// INSERT with automatic failover + retry
  static Future<Map<String, dynamic>> routerInsert(
    String table,
    Map<String, dynamic> data,
  ) async {
    if (_circuitOpen) return await _fallbackInsert(table, data);

    for (int attempt = 0; attempt <= AppConfig.maxRetries; attempt++) {
      try {
        final rows = await client
            .from(table)
            .insert(data)
            .select()
            .timeout(Duration(seconds: AppConfig.requestTimeoutSec));
        _recordSuccess();
        return Map<String, dynamic>.from(rows.first);
      } catch (e) {
        if (!_isTransientError(e)) rethrow;
        if (attempt < AppConfig.maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          continue;
        }
        _recordFailure('INSERT $table');
        debugPrint(
            '[BackendRouter] ↪️ Fallback INSERT $table after primary failure');
        return await _fallbackInsert(table, data);
      }
    }
    throw Exception('Unreachable');
  }

  /// UPDATE with automatic failover + retry
  static Future<void> routerUpdate(
    String table,
    String id,
    Map<String, dynamic> data,
  ) async {
    if (_circuitOpen) return await _fallbackUpdate(table, id, data);

    for (int attempt = 0; attempt <= AppConfig.maxRetries; attempt++) {
      try {
        await client
            .from(table)
            .update(data)
            .eq('id', id)
            .timeout(Duration(seconds: AppConfig.requestTimeoutSec));
        _recordSuccess();
        return;
      } catch (e) {
        if (!_isTransientError(e)) rethrow;
        if (attempt < AppConfig.maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          continue;
        }
        _recordFailure('UPDATE $table');
        debugPrint(
            '[BackendRouter] ↪️ Fallback UPDATE $table after primary failure');
        return await _fallbackUpdate(table, id, data);
      }
    }
    throw Exception('Unreachable');
  }

  /// DELETE with automatic failover + retry
  static Future<void> routerDelete(String table, String id) async {
    if (_circuitOpen) return await _fallbackDelete(table, id);

    for (int attempt = 0; attempt <= AppConfig.maxRetries; attempt++) {
      try {
        await client
            .from(table)
            .delete()
            .eq('id', id)
            .timeout(Duration(seconds: AppConfig.requestTimeoutSec));
        _recordSuccess();
        return;
      } catch (e) {
        if (!_isTransientError(e)) rethrow;
        if (attempt < AppConfig.maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          continue;
        }
        _recordFailure('DELETE $table');
        debugPrint(
            '[BackendRouter] ↪️ Fallback DELETE $table after primary failure');
        return await _fallbackDelete(table, id);
      }
    }
    throw Exception('Unreachable');
  }

  /// RPC with automatic failover + retry
  static Future<dynamic> routerRpc(
    String function, {
    Map<String, dynamic>? params,
  }) async {
    if (_circuitOpen) return await _fallbackRpc(function, params ?? {});

    for (int attempt = 0; attempt <= AppConfig.maxRetries; attempt++) {
      try {
        final result = await client
            .rpc(function, params: params ?? {})
            .timeout(Duration(seconds: AppConfig.requestTimeoutSec));
        _recordSuccess();
        return result;
      } catch (e) {
        if (!_isTransientError(e)) rethrow;
        if (attempt < AppConfig.maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          continue;
        }
        _recordFailure('RPC $function');
        debugPrint(
            '[BackendRouter] ↪️ Fallback RPC $function after primary failure');
        return await _fallbackRpc(function, params ?? {});
      }
    }
    throw Exception('Unreachable');
  }

  // ─── STORAGE FAILOVER ───────────────────────────────────────
  // Upload file to primary (Supabase storage); on transient fail → fallback
  // GET public URL: if primary, use Supabase getPublicUrl; if fallback, construct URL

  /// Upload a binary file to a storage bucket (Supabase primary → fallback)
  static Future<void> routerStorageUpload(
    String bucket,
    String path,
    Uint8List bytes, {
    String contentType = 'application/octet-stream',
    bool upsert = false,
  }) async {
    if (_circuitOpen) {
      // Fallback: PUT to local storage endpoint
      final res = await http
          .put(
            Uri.parse('${AppConfig.fallbackApiUrl}/storage/v1/bucket/$bucket/$path'),
            headers: _fallbackHeaders(contentType: contentType),
            body: bytes,
          )
          .timeout(Duration(seconds: AppConfig.requestTimeoutSec));
      if (res.statusCode != 200 && res.statusCode != 201) {
        throw Exception('Fallback storage upload $bucket/$path: ${res.statusCode}');
      }
      debugPrint('[BackendRouter] ↪️ Fallback storage upload $bucket/$path');
      return;
    }

    for (int attempt = 0; attempt <= AppConfig.maxRetries; attempt++) {
      try {
        await client.storage
            .from(bucket)
            .uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: contentType, upsert: upsert),
            )
            .timeout(Duration(seconds: AppConfig.requestTimeoutSec));
        _recordSuccess();
        return;
      } catch (e) {
        if (!_isTransientError(e)) rethrow;
        if (attempt < AppConfig.maxRetries) {
          await Future.delayed(Duration(milliseconds: 500 * (attempt + 1)));
          continue;
        }
        _recordFailure('Storage upload $bucket/$path');
        debugPrint(
            '[BackendRouter] ↪️ Fallback storage upload $bucket/$path after primary failure');
        // fallback
        final res = await http
            .put(
              Uri.parse('${AppConfig.fallbackApiUrl}/storage/v1/bucket/$bucket/$path'),
              headers: _fallbackHeaders(contentType: contentType),
              body: bytes,
            )
            .timeout(Duration(seconds: AppConfig.requestTimeoutSec));
        if (res.statusCode != 200 && res.statusCode != 201) {
          throw Exception('Fallback storage upload $bucket/$path: ${res.statusCode}');
        }
        return;
      }
    }
    throw Exception('Unreachable');
  }

  /// Get public URL for a stored file (primary → fallback)
  static String routerStorageGetPublicUrl(String bucket, String path) {
    if (_circuitOpen) {
      return '${AppConfig.fallbackApiUrl}/storage/v1/bucket/$bucket/$path';
    }
    return client.storage.from(bucket).getPublicUrl(path);
  }
}

/// Helper generik CRUD — now uses BackendRouter for automatic failover.
class Crud<T extends Map<String, dynamic>> {
  final String table;
  final Map<String, dynamic> Function() _defaults;

  Crud(this.table, {Map<String, dynamic> Function()? defaults})
      : _defaults = defaults ?? (() => <String, dynamic>{});

  Future<List<Map<String, dynamic>>> list({
    String? order,
    bool ascending = true,
    int? limit,
  }) async {
    return await Api.routerSelect(table,
        order: order, ascending: ascending, limit: limit);
  }

  Future<List<Map<String, dynamic>>> where(String column, Object value) async {
    return await Api.routerSelect(table, eq: {column: value.toString()});
  }

  Future<Map<String, dynamic>?> get(String id) async {
    final rows = await Api.routerSelect(table, eq: {'id': id}, limit: 1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    return await Api.routerInsert(table, {..._defaults(), ...data});
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await Api.routerUpdate(table, id, data);
  }

  Future<void> delete(String id) async {
    await Api.routerDelete(table, id);
  }
}