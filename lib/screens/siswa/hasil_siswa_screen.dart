import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../../widgets/state_views.dart';

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
      return ErrorState(message: _error!, onRetry: _load);
    }
    if (_rows.isEmpty) {
      return const EmptyState(
        icon: Icons.assessment_outlined,
        title: 'Belum ada hasil ujian',
        subtitle: 'Nilai akan muncul setelah kamu mengumpulkan ujian.',
      );
    }
    final dinilai = _rows.where((r) => r['dinilai'] == true).toList();
    final tuntas = dinilai.where((r) => ((r['nilai'] as num?)?.round() ?? 0) >= 75).length;
    // Rata-rata: pakai SEMUA hasil (dinilai & belum dinilai), karena nilai sistem
    // udah terhitung (untuk pg/jodoh). essay = koreksi manual guru (dinilai=false).
    final semuaDgnNilai = _rows.where((r) => r['nilai'] != null).toList();
    final totalNilai = semuaDgnNilai.fold<int>(0, (sum, r) => sum + ((r['nilai'] as num?)?.round() ?? 0));
    final rata = semuaDgnNilai.isEmpty ? 0 : (totalNilai / semuaDgnNilai.length).round();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _ResultsSummary(total: _rows.length, rated: dinilai.length, passed: tuntas, average: rata),
          const SizedBox(height: 12),
          for (int i = 0; i < _rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Builder(builder: (context) {
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
                            if (r['selesai_pada'] != null) r['selesai_pada'].toString(),
                            'B/S/K: ${r['benar'] ?? 0}/${r['salah'] ?? 0}/${r['kosong'] ?? 0}',
                          ].where((e) => '$e'.isNotEmpty).join(' • '),
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        if (pelanggaran > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('$pelanggaran pelanggaran keluar layar',
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
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          ((r['nilai'] as num?)?.round()).toString() == 'null' ? '—' : '${(r['nilai'] as num).round()}',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: _penilaianColor(dinilai, nilai)),
                        ),
                        if (!dinilai)
                          Text('menunggu koreksi',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
            }),
          ],
        ],
      ),
    );
  }
}

class _ResultsSummary extends StatelessWidget {
  final int total;
  final int rated;
  final int passed;
  final int average;
  const _ResultsSummary({required this.total, required this.rated, required this.passed, required this.average});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Ringkasan hasil', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Row(children: [
          Text('$average', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          const Text('rata-rata nilai', style: TextStyle(color: Colors.white, fontSize: 13)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _summaryItem('$total', 'Total'),
          _summaryItem('$rated', 'Dinilai'),
          _summaryItem('$passed', 'Tuntas'),
        ]),
      ]),
    );
  }

  Widget _summaryItem(String value, String label) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      );
}
