import 'package:flutter/material.dart';

import '../../services/api.dart';
import '../../widgets/state_views.dart';

class RekapPanitiaScreen extends StatefulWidget {
  const RekapPanitiaScreen({super.key});

  @override
  State<RekapPanitiaScreen> createState() => _RekapPanitiaScreenState();
}

class _RekapPanitiaScreenState extends State<RekapPanitiaScreen> {
  List<Map<String, dynamic>> _rows = [];
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
      final rows = await Api.client
          .from('hasil_ujian')
          .select(
              '*,peserta_ujian!inner(ujian!inner(nama,mata_pelajaran(nama)),siswa!inner(nama,nis))')
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: const Text('Rekap Hasil Ujian')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_rows.isEmpty) {
      return const Center(
          child: Text('Belum ada hasil ujian',
              style: TextStyle(color: Colors.grey)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final h = _rows[i];
          final peserta = h['peserta_ujian'];
          final siswa = peserta is Map ? peserta['siswa'] : null;
          final ujian = peserta is Map ? peserta['ujian'] : null;
          final mp = ujian is Map ? ujian['mata_pelajaran'] : null;
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              title: Text(
                  siswa is Map ? siswa['nama'] ?? '' : '',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('NIS: ${siswa is Map ? siswa['nis'] ?? '-' : '-'}'),
                  Text('Ujian: ${ujian is Map ? ujian['nama'] ?? '-' : '-'}'),
                  Text('Mapel: ${mp is Map ? mp['nama'] ?? '-' : '-'}'),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _StatChip('Benar: ${h['jumlah_benar'] ?? 0}',
                          const Color(0xFFE8F5E9)),
                      const SizedBox(width: 6),
                      _StatChip('Salah: ${h['jumlah_salah'] ?? 0}',
                          const Color(0xFFFFEBEE)),
                      const SizedBox(width: 6),
                      _StatChip('Nilai: ${h['nilai'] ?? 0}',
                          const Color(0xFFE3F2FD)),
                    ],
                  ),
                ],
              ),
              trailing: Text(
                '${h['skor'] ?? 0}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color bg;
  const _StatChip(this.label, this.bg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }
}