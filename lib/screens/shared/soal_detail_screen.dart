import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../../widgets/state_views.dart';

/// Detail soal: tampilkan semua isi soal lengkap (opsi, kunci, pembahasan, gambar).
/// Dipakai dari Bank Soal (drill-down) dan dari Ujian List.
class SoalDetailScreen extends StatefulWidget {
  final String soalId;
  const SoalDetailScreen({super.key, required this.soalId});

  @override
  State<SoalDetailScreen> createState() => _SoalDetailScreenState();
}

class _SoalDetailScreenState extends State<SoalDetailScreen> {
  Map<String, dynamic>? _soal;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await Api.client.from('bank_soal').select('*').eq('id', widget.soalId).limit(1);
      if (!mounted) return;
      setState(() {
        _soal = rows.isNotEmpty ? rows.first as Map<String, dynamic> : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat soal: $e';
        _loading = false;
      });
    }
  }

  /// Dekode opsi jodoh (JSON array [A1, B1, A2, B2, ...]).
  List<String> _opsiJodoh(Map<String, dynamic> s) {
    final opsi = s['opsi'];
    if (opsi == null) return [];
    List raw;
    if (opsi is List) {
      raw = opsi;
    } else if (opsi is String) {
      try {
        raw = jsonDecode(opsi) as List;
      } catch (_) {
        return [opsi];
      }
    } else {
      return [];
    }
    return raw.map((e) => e.toString()).toList();
  }

  /// Parse kunci jodoh: ambil "map" dari kunci JSON.
  Map<String, String> _kunciJodoh(Map<String, dynamic> s) {
    final kunci = s['kunci'];
    if (kunci == null) return {};
    Map<String, dynamic> kObj;
    if (kunci is Map<String, dynamic>) {
      kObj = kunci;
    } else if (kunci is String) {
      try {
        kObj = Map<String, dynamic>.from(jsonDecode(kunci) as Map);
      } catch (_) {
        return {};
      }
    } else {
      return {};
    }
    final mapVal = kObj['map'];
    if (mapVal == null) return {};
    Map<String, String> m;
    if (mapVal is String) {
      try {
        m = Map<String, String>.from(jsonDecode(mapVal) as Map);
      } catch (_) {
        return {};
      }
    } else if (mapVal is Map) {
      m = mapVal.map((k, v) => MapEntry(k.toString(), v.toString()));
    } else {
      return {};
    }
    return m;
  }

  Widget _sectionHeader(String label, {Color? color}) {
    return Container(
      margin: const EdgeInsets.only(top: 14, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? AppTheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label.toUpperCase(),
          style: TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _card(String title, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
          child: ErrorState(message: _error!, onRetry: _load));
    }
    final s = _soal;
    if (s == null) {
      return const Center(child: EmptyState(icon: Icons.help_outline, title: 'Soal tidak ditemukan'));
    }

    final jenis = s['jenis']?.toString() ?? 'pg';
    final soal = s['soal']?.toString() ?? '';
    final pembahasan = s['pembahasan']?.toString() ?? '';
    final bobot = s['bobot'];
    final gambarUrl = s['gambar_url']?.toString();

    // Opsi PG / JODOH
    List<String> opsiList = [];
    Map<String, String> kunciJodoh = {};
    if (jenis == 'jodoh') {
      opsiList = _opsiJodoh(s);
      kunciJodoh = _kunciJodoh(s);
    } else {
      final opsi = s['opsi'];
      if (opsi is List) {
        opsiList = opsi.map((e) => e.toString()).toList();
      } else if (opsi is String) {
        try {
          opsiList = (jsonDecode(opsi) as List).map((e) => e.toString()).toList();
        } catch (_) {
          opsiList = [opsi];
        }
      }
    }

    // Kunci jawaban PG / ESSAY
    final kunci = s['kunci'];
    String kunciLabel = '';
    if (jenis == 'pg') {
      if (kunci is Map && kunci['jawaban'] != null) {
        kunciLabel = kunci['jawaban'].toString();
      } else if (kunci is String) {
        try {
          final m = jsonDecode(kunci) as Map;
          kunciLabel = (m['jawaban'] ?? '').toString();
        } catch (_) {
          kunciLabel = kunci;
        }
      }
    } else if (jenis == 'essay') {
      if (kunci is Map && kunci['pedoman'] != null) {
        kunciLabel = kunci['pedoman'].toString();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Detail Soal', style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            // Badge jenis
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: jenis == 'essay'
                        ? const Color(0xFFFEF3C7)
                        : jenis == 'jodoh'
                            ? const Color(0xFFE0E7FF)
                            : const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    jenis.toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: jenis == 'essay'
                            ? const Color(0xFF92400E)
                            : jenis == 'jodoh'
                                ? const Color(0xFF4338CA)
                                : AppTheme.primary),
                  ),
                ),
                const Spacer(),
                if (bobot != null)
                  Text('Bobot: $bobot',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),

            const SizedBox(height: 14),

            // SOAL
            _card('Soal',
                Text(soal,
                    style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w500))),

            // GAMBAR (kalau ada)
            if (gambarUrl != null && gambarUrl.isNotEmpty)
              _card(
                'Gambar Soal',
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    gambarUrl,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    loadingBuilder: (ctx, child, prog) =>
                        prog == null
                            ? child
                            : const Padding(
                                padding: EdgeInsets.all(20),
                                child: Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))),
                  ),
                ),
              ),

            // OPSI / JODOH
            if (opsiList.isNotEmpty) ...[
              jenis == 'jodoh'
                  ? _card('Jawaban Jodoh (${opsiList.length ~/ 2} pasang)',
                      _buildJodohDetail(opsiList, kunciJodoh))
                  : _card('Pilihan Jawaban',
                      _buildPilihanJawaban(opsiList, kunciLabel)),
            ],

            // KUNCI / PEDOMAN ESSAY
            if (jenis == 'essay' && kunciLabel.isNotEmpty)
              _card('Pedoman Jawaban',
                  Text(kunciLabel,
                      style: const TextStyle(fontSize: 13, height: 1.5))),

            // PEMBAHASAN
            if (pembahasan.isNotEmpty)
              _card(
                  'Pembahasan',
                  Text(pembahasan,
                      style: const TextStyle(fontSize: 13, height: 1.5))),
          ],
        ),
      ),
    );
  }

  Widget _buildPilihanJawaban(List<String> opsi, String kunci) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < opsi.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: opsi[i] == kunci ? AppTheme.primary : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color:
                            opsi[i] == kunci ? AppTheme.primary : const Color(0xFFE2E8F0)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    String.fromCharCode(65 + i),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color:
                            opsi[i] == kunci ? Colors.white : const Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    opsi[i],
                    style: TextStyle(
                        fontSize: 13,
                        color: opsi[i] == kunci
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF334155),
                        fontWeight:
                            opsi[i] == kunci ? FontWeight.w600 : FontWeight.normal),
                  ),
                ),
                if (opsi[i] == kunci)
                  const Icon(Icons.check_circle,
                      size: 18, color: AppTheme.primary),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildJodohDetail(List<String> opsi, Map<String, String> kunciMap) {
    final nRow = opsi.length ~/ 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Soal jodoh: ${nRow} pasangan. Setiap A harus cocok dengan B yang benar.',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < nRow; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4338CA).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF4338CA)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                              color: Color(0xFF4338CA), shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            i * 2 < opsi.length ? opsi[i * 2] : '',
                            style: const TextStyle(fontSize: 12, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Panah
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Icon(Icons.arrow_forward,
                      size: 16,
                      color: kunciMap['$i'] == null
                          ? Colors.grey
                          : AppTheme.primary),
                ),
                const SizedBox(width: 8),
                // B
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E7FF).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color:
                              kunciMap['$i'] == null
                                  ? const Color(0xFFE2E8F0)
                                  : AppTheme.primary),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: kunciMap['$i'] == null
                                ? const Color(0xFFF1F5F9)
                                : AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            String.fromCharCode(97 + i),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: kunciMap['$i'] == null
                                    ? const Color(0xFF64748B)
                                    : Colors.white),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            i * 2 + 1 < opsi.length ? opsi[i * 2 + 1] : '',
                            style: const TextStyle(fontSize: 12, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
