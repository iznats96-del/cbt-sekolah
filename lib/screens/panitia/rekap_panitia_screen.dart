import 'package:flutter/material.dart';

import '../../core/design.dart';
import '../../services/api.dart';
import '../../widgets/state_views.dart';
import '../../widgets/dashboard_header.dart';

class RekapPanitiaScreen extends StatefulWidget {
  const RekapPanitiaScreen({super.key});

  @override
  State<RekapPanitiaScreen> createState() => _RekapPanitiaScreenState();
}

class _RekapPanitiaScreenState extends State<RekapPanitiaScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  final _cari = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await Api.client
          .from('hasil_ujian')
          .select('*,peserta_ujian!inner(ujian!inner(nama,mata_pelajaran(nama)),siswa!inner(nama,nis))')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat rekap: $e';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _cari.text.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows.where((h) {
      final p = h['peserta_ujian'];
      if (p is! Map) return false;
      final s = p['siswa'];
      final u = p['ujian'];
      final m = u is Map ? u['mata_pelajaran'] : null;
      return '${s is Map ? s['nama'] : ''} ${s is Map ? s['nis'] : ''} '
              '${u is Map ? u['nama'] : ''} ${m is Map ? m['nama'] : ''}'
          .toLowerCase()
          .contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: DashboardHeader(
        title: 'REKAP HASIL UJIAN',
        stats: [('hasil', '${_rows.length}')],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Cbt.blue));
    }
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Cbt.searchField(
            controller: _cari,
            hint: 'Cari nama siswa, NIS, atau ujian…',
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: _filtered.isEmpty
              ? Cbt.empty(
                  icon: Icons.search_off_rounded,
                  title: _rows.isEmpty ? 'Belum ada hasil ujian' : 'Tidak ada yang cocok',
                  subtitle: _rows.isEmpty ? null : 'Coba kata kunci lain.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 9),
                    itemBuilder: (context, i) => _buildCard(_filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCard(Map<String, dynamic> h) {
    final p = h['peserta_ujian'];
    final siswa = p is Map ? p['siswa'] : null;
    final ujian = p is Map ? p['ujian'] : null;
    final mp = ujian is Map ? ujian['mata_pelajaran'] : null;
    final nilai = h['nilai'];
    final warna = nilai is num && nilai < 75 ? Cbt.red : Cbt.teal;
    return Cbt.card(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Cbt.blue.withValues(alpha: 0.1),
            child: const Icon(Icons.person_outline, color: Cbt.blue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(siswa is Map ? '${siswa['nama'] ?? ''}' : '-',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Cbt.ink)),
                const SizedBox(height: 3),
                Text('NIS ${siswa is Map ? siswa['nis'] ?? '-' : '-'}',
                    style: Cbt.caption),
                const SizedBox(height: 3),
                Text('${ujian is Map ? ujian['nama'] ?? '' : ''}'
                    '${mp is Map && '${mp['nama']}'.isNotEmpty ? ' • ${mp['nama']}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cbt.caption),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 5,
                  children: [
                    _chip('Benar ${h['jumlah_benar'] ?? 0}', Cbt.teal),
                    _chip('Salah ${h['jumlah_salah'] ?? 0}', Cbt.red),
                    _chip('Kosong ${h['jumlah_kosong'] ?? 0}', Cbt.muted),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              Text('$nilai', style: Cbt.display.copyWith(fontSize: 26, color: warna)),
              Text('NILAI', style: Cbt.overline.copyWith(fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
        child: Text(t, style: TextStyle(fontSize: 10, color: c, fontWeight: FontWeight.w600)),
      );
}
