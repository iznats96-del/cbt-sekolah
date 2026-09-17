import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Penyimpanan LOKAL jawaban ujian (anti-hilang walau HP mati / offline).
///
/// Design:
/// - Tiap set jawaban LANGSUNG disimpan ke SharedPreferences (instan, tanpa internet)
/// - Saat kumpul, jawaban dibaca dari lokal lalu dikirim ke Supabase (batch)
/// - Key unik per peserta: `jwb_<pesertaId>`
class JawabanStore {
  final String pesertaId;
  JawabanStore(this.pesertaId);

  String get _key => 'jwb_$pesertaId';

  /// Simpan seluruh map jawaban { soalId: {jawaban, ragu} } ke HP.
  Future<void> saveAll(Map<String, String?> jawaban, Map<String, bool> ragu) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final data = <String, dynamic>{};
      for (final e in jawaban.entries) {
        data[e.key] = {
          'jawaban': e.value ?? '',
          'ragu': ragu[e.key] ?? false,
        };
      }
      await sp.setString(_key, jsonEncode(data));
    } catch (_) {}
  }

  /// Baca kembali jawaban yang tersimpan di HP (untuk resume).
  Future<Map<String, Map<String, dynamic>>> loadAll() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString(_key);
      if (raw == null) return {};
      final m = jsonDecode(raw);
      if (m is! Map) return {};
      return {
        for (final e in m.entries)
          '${e.key}': Map<String, dynamic>.from(e.value as Map)
      };
    } catch (_) {
      return {};
    }
  }

  /// Tandai jawaban mana yang SUDAH berhasil dikirim ke server.
  Future<void> markSynced(Set<String> soalIds) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setStringList('${_key}_synced', soalIds.toList());
    } catch (_) {}
  }

  Future<Set<String>> getSynced() async {
    try {
      final sp = await SharedPreferences.getInstance();
      return (sp.getStringList('${_key}_synced') ?? []).toSet();
    } catch (_) {
      return {};
    }
  }

  /// Hapus data lokal peserta ini (dipanggil setelah ujian benar-benar selesai).
  Future<void> clear() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.remove(_key);
      await sp.remove('${_key}_synced');
    } catch (_) {}
  }
}
