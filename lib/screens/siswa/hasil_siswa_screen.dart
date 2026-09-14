import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';

Color _penilaianColor(bool dinilai, int nilai) {
  if (!dinilai) return Colors.grey;
  return nilai >= 75 ? AppTheme.secondary : AppTheme.danger;
}

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
      final rows = await Api.client.rpc('my_hasil');
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(rows as List);
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
          final ujian = r['ujian']?.toString() ?? '';
          final mapelNama = r['mapel']?.toString() ?? '';
          final dinilai = r['dinilai'] == true;
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
                        Text(ujian,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          [
                            mapelNama,
                            if (r['selesai_pada'] != null) '${r['selesai_pada']}',
                            'B/S/K: ${r['benar'] ?? 0}/${r['salah'] ?? 0}/${r['kosong'] ?? 0}',
                          ].where((e) => '$e'.isNotEmpty).join(' • '),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        if (pelanggaran > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('⚠ $pelanggaran pelanggaran keluar layar',
                                style: const TextStyle(
                                    fontSize: 12, color: AppTheme.danger)),
                          ),
                        if (!dinilai)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text('Menunggu kunci/koreksi guru',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.orange,
                                    fontStyle: FontStyle.italic)),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: (dinilai && nilai >= 75
                              ? AppTheme.secondary
                              : dinilai ? AppTheme.danger : Colors.grey)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      dinilai ? '$nilai' : '—',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _penilaianColor(dinilai, nilai)),
                    ),
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