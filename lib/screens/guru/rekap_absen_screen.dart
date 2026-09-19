import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';

/// Rekap absen harian: per KELAS (siapa hadir / belum) + ringkasan per JURUSAN.
class RekapAbsenScreen extends StatefulWidget {
  const RekapAbsenScreen({super.key});

  @override
  State<RekapAbsenScreen> createState() => _RekapAbsenScreenState();
}

class _RekapAbsenScreenState extends State<RekapAbsenScreen> {
  List<Map<String, dynamic>> _siswa = [];
  Map<String, String> _hadir = {}; // siswa_id -> status
  bool _loading = true;
  String _q = '';
  String get _today {
    final n = DateTime.now();
    return '${n.day.toString().padLeft(2, '0')}/${n.month.toString().padLeft(2, '0')}/${n.year}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tgl = DateTime.now().toIso8601String().split('T').first;
      final res = await Future.wait([
        Api.client
            .from('siswa')
            .select('id,nama,nis,kelas(nama,jurusan(nama,singkatan))')
            .order('nama'),
        Api.client.from('kehadiran').select('siswa_id,status').eq('tanggal', tgl),
      ]);
      if (!mounted) return;
      final had = <String, String>{};
      for (final r in (res[1] as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        had['${m['siswa_id']}'] = '${m['status'] ?? ''}';
      }
      setState(() {
        _siswa = List<Map<String, dynamic>>.from(res[0] as List);
        _hadir = had;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _kelasOf(Map<String, dynamic> s) {
    final k = s['kelas'];
    return (k is Map ? '${k['nama'] ?? ''}' : '').trim();
  }

  String _jurusanOf(Map<String, dynamic> s) {
    final k = s['kelas'];
    final j = (k is Map) ? k['jurusan'] : null;
    if (j is Map && '${j['singkatan'] ?? ''}'.isNotEmpty) return '${j['singkatan']}';
    return '';
  }

  bool _isHadir(Map<String, dynamic> s) => _hadir['${s['id']}'] == 'hadir';

  List<Map<String, dynamic>> get _filtered {
    final q = _q.trim().toLowerCase();
    final list = q.isEmpty
        ? _siswa
        : _siswa.where((s) {
            final nama = '${s['nama'] ?? ''}'.toLowerCase();
            final nis = '${s['nis'] ?? ''}'.toLowerCase();
            return nama.contains(q) || nis.contains(q);
          }).toList();
    list.sort((a, b) {
      final ha = _isHadir(a) ? 1 : 0;
      final hb = _isHadir(b) ? 1 : 0;
      return ha.compareTo(hb); // belum absen di atas
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: Text('Rekap Absen • $_today')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: TextField(
                    onChanged: (v) => setState(() => _q = v),
                    decoration: InputDecoration(
                      hintText: 'Cari nama / NIS...',
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 18),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                _ringkasan(),
                Expanded(child: _daftarKelas()),
              ],
            ),
    );
  }

  Widget _ringkasan() {
    // agregat per jurusan
    final agg = <String, List<int>>{}; // singkatan -> [hadir, total]
    int hadirAll = 0;
    for (final s in _siswa) {
      final j = _jurusanOf(s);
      final key = j.isEmpty ? '-' : j;
      agg.putIfAbsent(key, () => [0, 0]);
      agg[key]![1]++;
      if (_isHadir(s)) {
        agg[key]![0]++;
        hadirAll++;
      }
    }
    final keys = agg.keys.toList()..sort();
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hadir $hadirAll/${_siswa.length} murid hari ini',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in keys)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Text(k, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('${agg[k]![0]}/${agg[k]![1]} hadir',
                          style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _daftarKelas() {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final s in _filtered) {
      final k = _kelasOf(s);
      final key = k.isEmpty ? '(tanpa kelas)' : k;
      (groups[key] ??= []).add(s);
    }
    final keys = groups.keys.toList()..sort();
    if (keys.isEmpty) {
      return const Center(
          child: Text('Tidak ada murid', style: TextStyle(color: Colors.grey)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: keys.length,
        itemBuilder: (context, i) {
          final nama = keys[i];
          final list = groups[nama]!;
          final hadir = list.where(_isHadir).length;
          final belum = list.where((s) => !_isHadir(s)).toList();
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ExpansionTile(
              shape: const Border(),
              leading: CircleAvatar(
                backgroundColor: hadir == list.length
                    ? AppTheme.secondary.withOpacity(0.15)
                    : AppTheme.accent.withOpacity(0.15),
                child: Text('$hadir',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: hadir == list.length
                            ? AppTheme.secondary
                            : AppTheme.accent)),
              ),
              title: Text(nama,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: Text('$hadir/${list.length} hadir',
                  style: const TextStyle(fontSize: 12)),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [
                if (belum.isNotEmpty) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text('BELUM ABSEN:',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.danger)),
                    ),
                  ),
                  for (final s in belum)
                    _row(s, false),
                  const Divider(height: 16),
                ],
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text('SUDAH HADIR:',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondary)),
                  ),
                ),
                for (final s in list.where(_isHadir)) _row(s, true),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _row(Map<String, dynamic> s, bool hadir) {
    final st = _hadir['${s['id']}'] ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(hadir ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: hadir ? AppTheme.secondary : Colors.grey[400]),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${s['nama'] ?? '?'}',
                style: const TextStyle(fontSize: 13)),
          ),
          if (st.isNotEmpty && st != 'hadir')
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(st,
                  style: const TextStyle(
                      fontSize: 10.5, color: AppTheme.accent)),
            )
          else
            Text('${s['nis'] ?? ''}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }
}
