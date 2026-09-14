import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';

class HasilSiswaScreen extends StatefulWidget {
  const HasilSiswaScreen({super.key});

  @override
  State<HasilSiswaScreen> createState() => _HasilSiswaScreenState();
}

class _HasilSiswaScreenState extends State<HasilSiswaScreen> {
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
      final userId = Api.user?.id;
      if (userId == null) {
        setState(() {
          _rows = [];
          _loading = false;
        });
        return;
      }
      // ambil siswa dari profil
      final siswaRows = await Api.client
          .from('siswa')
          .select('id')
          .eq('profile_id', userId)
          .limit(1);
      if (siswaRows.isEmpty) {
        setState(() {
          _rows = [];
          _loading = false;
        });
        return;
      }
      final siswaId = siswaRows.first['id'].toString();
      // ambil semua peserta ujian milik siswa, lalu hasilnya
      final peserta = await Api.client
          .from('peserta_ujian')
          .select('id,ujian(nama,mata_pelajaran(nama))')
          .eq('siswa_id', siswaId)
          .order('created_at', ascending: false);
      final pesertaIds = peserta.map((p) => p['id']).toList();
      List<Map<String, dynamic>> rows = [];
      if (pesertaIds.isNotEmpty) {
        rows = List<Map<String, dynamic>>.from(await Api.client
            .from('hasil_ujian')
            .select('*,peserta_ujian!inner(id,ujian(nama,mata_pelajaran(nama)))')
            .inFilter('peserta_ujian_id', pesertaIds));
      }
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat hasil: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.danger, size: 40),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Muat Ulang')),
            ],
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return const Center(
        child: Text('Belum ada hasil ujian.', style: TextStyle(color: Colors.grey)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final r = _rows[i];
          final p = r['peserta_ujian'];
          final ujian = p is Map ? p['ujian'] : null;
          final mapel = ujian is Map ? ujian['mata_pelajaran'] : null;
          final nama = ujian is Map ? ujian['nama']?.toString() ?? '' : '';
          final mapelNama =
              mapel is Map ? mapel['nama']?.toString() ?? '' : '';
          final nilai = (r['nilai'] as num?)?.round() ?? 0;
          final pelanggaran = (r['pelanggaran'] as num?)?.toInt() ?? 0;
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nama,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text([mapelNama, 'B/S/K: ${r['jumlah_benar']}/${r['jumlah_salah']}/${r['jumlah_kosong']}'.toString()]
                            .where((e) => e.isNotEmpty)
                            .join(' • '),
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        if (pelanggaran > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('⚠ $pelanggaran pelanggaran keluar layar',
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.danger)),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: (nilai >= 75 ? AppTheme.secondary : AppTheme.danger)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('$nilai',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: nilai >= 75 ? AppTheme.secondary : AppTheme.danger)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}