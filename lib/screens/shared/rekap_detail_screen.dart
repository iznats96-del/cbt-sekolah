import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';

/// Detail jawaban 1 murid pada 1 ujian (untuk guru/admin) — pakai RPC rekap_detail.
/// Tampilkan: PG (jawaban murid vs kunci, benar/salah) + esai (jawaban + nilai).
class RekapDetailScreen extends StatefulWidget {
  final Map<String, dynamic> ujian;
  final String pesertaId;
  const RekapDetailScreen({super.key, required this.ujian, required this.pesertaId});

  @override
  State<RekapDetailScreen> createState() => _RekapDetailScreenState();
}

class _RekapDetailScreenState extends State<RekapDetailScreen> {
  Map<String, dynamic>? _murid;
  bool _loading = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Api.client.rpc('rekap_detail', params: {'p_ujian': widget.ujian['id']});
      final list = (res is List) ? res : <dynamic>[];
      final m = list.firstWhere(
        (e) => (e is Map) && '${e['peserta_id']}' == widget.pesertaId,
        orElse: () => null,
      );
      if (!mounted) return;
      setState(() {
        _murid = m == null ? null : Map<String, dynamic>.from(m as Map);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _err = '$e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _murid;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: Text('Jawaban: ${m?['nama'] ?? '...'}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err != null
              ? Center(child: Text(_err!))
              : m == null
                  ? const Center(child: Text('Peserta tidak ditemukan'))
                  : _buildBody(m),
    );
  }

  Widget _buildBody(Map<String, dynamic> m) {
    final det = (m['detail'] as List?) ?? [];
    final benar = (m['benar'] as num?)?.toInt() ?? 0;
    final salah = (m['salah'] as num?)?.toInt() ?? 0;
    final kosong = (m['kosong'] as num?)?.toInt() ?? 0;
    final totalPg = benar + salah + kosong;
    final nilai = m['nilai'];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${m['nama']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('NIS ${m['nis']} • ${m['status'] ?? '-'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const Divider(height: 20),
                Row(
                  children: [
                    _stat('Benar', '$benar', AppTheme.secondary),
                    const SizedBox(width: 8),
                    _stat('Salah', '$salah', AppTheme.danger),
                    const SizedBox(width: 8),
                    _stat('Kosong', '$kosong', Colors.grey),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.insights, size: 16, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text('PG benar: ', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                    Text('$benar/$totalPg',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('Nilai ${nilai ?? '—'}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < det.length; i++) _soalCard(i + 1, Map<String, dynamic>.from(det[i] as Map)),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _stat(String label, String val, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text(val, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 18)),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _soalCard(int no, Map<String, dynamic> s) {
    final jenis = '${s['jenis'] ?? 'pg'}';
    final jwbn = s['jawaban'] == null ? '' : '${s['jawaban']}';
    final kunci = s['kunci'] == null ? null : '${s['kunci']}';
    final jawabBetul = s['benar'];
    final nilaiEsai = s['nilai_esai'];
    Color warn;
    String badge;
    if (jenis == 'essay') {
      warn = AppTheme.accent;
      badge = 'ESSAY';
    } else if (jawabBetul == true) {
      warn = AppTheme.secondary;
      badge = 'BENAR';
    } else if (jwbn.isEmpty) {
      warn = Colors.grey;
      badge = 'KOSONG';
    } else {
      warn = AppTheme.danger;
      badge = 'SALAH';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 13, backgroundColor: warn.withValues(alpha: 0.15),
                    child: Text('$no', style: TextStyle(fontSize: 11, color: warn, fontWeight: FontWeight.bold))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: warn.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Text('$jenis • $badge', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: warn)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('${s['soal']}', style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Jawaban murid:', style: TextStyle(fontSize: 10.5, color: Colors.grey[600])),
                  Text(jwbn.isEmpty ? '— tidak dijawab —' : jwbn,
                      style: const TextStyle(fontSize: 13, height: 1.4)),
                ],
              ),
            ),
            if (kunci != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.vpn_key_outlined, size: 13, color: AppTheme.secondary),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Kunci: $kunci',
                      style: const TextStyle(fontSize: 12, color: AppTheme.secondary, fontWeight: FontWeight.w600))),
                ],
              ),
            ],
            if (jenis == 'essay')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(Icons.grade_outlined, size: 13, color: AppTheme.accent),
                    const SizedBox(width: 6),
                    Text('Nilai esai (guru): ${nilaiEsai ?? 'belum dinilai'}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.accent, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
