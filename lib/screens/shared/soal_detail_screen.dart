import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/design.dart';
import '../../core/soal_preview.dart';
import '../../services/api.dart';
import '../../widgets/state_views.dart';
import '../../widgets/dashboard_header.dart';

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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 4, height: 15, decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF101F3C))),
              ],
            ),
            const SizedBox(height: 12),
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
    final isJodoh = SoalJodoh.isJodoh(jenis);
    final soal = s['soal']?.toString() ?? '';
    final pembahasan = s['pembahasan']?.toString() ?? '';
    final bobot = s['bobot'];
    final gambarUrl = s['gambar_url']?.toString();
    final jmlPasangan = SoalJodoh.jumlahPasangan(s['opsi']);

    // Opsi PG
    List<String> opsiList = [];
    {
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
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: const DashboardHeader(
        title: 'DETAIL SOAL',
        showBack: true,
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
                        : const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isJodoh ? 'MENJODOHKAN' : jenis.toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: jenis == 'essay'
                            ? const Color(0xFF92400E)
                            : AppTheme.primary),
                  ),
                ),
                const SizedBox(width: 10),
                if (isJodoh)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE9FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$jmlPasangan pasangan',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF5B21B6))),
                  ),
                const Spacer(),
                if (bobot != null)
                  Text('Bobot: $bobot',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),

            const SizedBox(height: 14),

            // SOAL (untuk jodoh: item kiri = soal, tanpa teks pertanyaan utama)
            if (isJodoh)
              _card(
                'Item Soal (kolom kiri)',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (soal.trim().isNotEmpty) ...[
                      Text(soal,
                          style: Cbt.adaptiveText(
                            soal,
                            const TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w600),
                          )),
                      const SizedBox(height: 8),
                    ],
                    Text(SoalJodoh.instruksi,
                        style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.5,
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 10),
                    for (var i = 0; i < SoalJodoh.kiri(s['opsi']).length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${i + 1}. ${SoalJodoh.kiri(s['opsi'])[i]}',
                          style: Cbt.adaptiveText(
                            '${i + 1}. ${SoalJodoh.kiri(s['opsi'])[i]}',
                            const TextStyle(
                                fontSize: 13.5, height: 1.4, color: Color(0xFF0F172A)),
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else
              _card('Soal',
                  Text(soal,
                      style: Cbt.adaptiveText(
                        soal,
                        const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w500),
                      ))),

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

            // PILIHAN KOLOM KANAN (jodoh)
            if (isJodoh && SoalJodoh.kanan(s['opsi']).isNotEmpty)
              _card(
                'Pilihan Jawaban (kolom kanan)',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < SoalJodoh.kanan(s['opsi']).length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${String.fromCharCode(65 + i)}. ',
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A))),
                            Expanded(
                              child: Text(SoalJodoh.kanan(s['opsi'])[i],
                                  style: Cbt.adaptiveText(
                                    SoalJodoh.kanan(s['opsi'])[i],
                                    const TextStyle(
                                        fontSize: 13.5,
                                        height: 1.4,
                                        color: Color(0xFF0F172A)),
                                  )),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

            // PASANGAN BENAR (jodoh)
            if (isJodoh && _pasanganBenar.isNotEmpty)
              _card(
                'Pasangan Benar',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final p in _pasanganBenar)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppTheme.secondary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('${p.$1 + 1}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.secondary)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${SoalJodoh.kiri(s['opsi']).elementAtOrNull(p.$1) ?? '-'} → '
                                '${SoalJodoh.kanan(s['opsi']).elementAtOrNull(p.$2) ?? '-'}',
                                style: const TextStyle(
                                    fontSize: 12.5, height: 1.4, color: Color(0xFF0F172A)),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

            // OPSI
            if (!isJodoh && opsiList.isNotEmpty) ...[
              _card('Pilihan Jawaban',
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

  List<(int, int)> get _pasanganBenar {
    final kunci = _soal?['kunci'];
    dynamic map = kunci is Map ? kunci['map'] : null;
    if (map is String) {
      try {
        map = jsonDecode(map);
      } catch (_) {
        map = null;
      }
    }
    if (map is! Map) return const [];
    final out = <(int, int)>[];
    for (final e in map.entries) {
      final a = int.tryParse(e.key.toString());
      final b = int.tryParse(e.value.toString());
      if (a != null && b != null) out.add((a, b));
    }
    out.sort((x, y) => x.$1.compareTo(y.$1));
    return out;
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

}
