import 'package:supabase_flutter/supabase_flutter.dart';

class Api {
  static SupabaseClient get client => Supabase.instance.client;

  static User? get user => client.auth.currentUser;

  static Future<Map<String, dynamic>?> currentProfile() async {
    final u = user;
    if (u == null) return null;
    final rows = await client.from('profiles').select().eq('id', u.id).limit(1);
    if (rows.isEmpty) return null;
    return rows.first as Map<String, dynamic>;
  }

  static String? get role => _cachedRole;

  static String? _cachedRole;

  static void setRole(String? r) => _cachedRole = r;

  static Future<bool> init() async {
    final u = user;
    if (u == null) return false;
    final p = await currentProfile();
    _cachedRole = p?['role'] as String?;
    return _cachedRole != null;
  }
}

/// Helper generik CRUD terhadap tabel Supabase.
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
    dynamic q = Api.client.from(table).select();
    if (order != null) q = q.order(order, ascending: ascending);
    if (limit != null) q = q.limit(limit);
    final rows = await q;
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> where(String column, Object value) async {
    final rows = await Api.client.from(table).select().eq(column, value);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>?> get(String id) async {
    final rows = await Api.client.from(table).select().eq('id', id).limit(1);
    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final rows =
        await Api.client.from(table).insert({..._defaults(), ...data}).select();
    return Map<String, dynamic>.from(rows.first);
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await Api.client.from(table).update(data).eq('id', id);
  }

  Future<void> delete(String id) async {
    await Api.client.from(table).delete().eq('id', id);
  }
}