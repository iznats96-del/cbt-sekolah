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

            // OPSI
            if (opsiList.isNotEmpty) ...[
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
