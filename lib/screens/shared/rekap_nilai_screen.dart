import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';

/// Rekap hasil ujian per rombel (X/XI/XII — TKJ / TSM / AKA) — admin & guru.
class RekapNilaiScreen extends StatefulWidget {
  const RekapNilaiScreen({super.key});

  @override
  State<RekapNilaiScreen> createState() => _RekapNilaiScreenState();
}

class _RekapNilaiScreenState extends State<RekapNilaiScreen> {
  List<Map<String, dynamic>> _ujian = [];
  Map<String, dynamic>? _selected;
  List<Map<String, dynamic>> _peserta = [];
  double _kkm = 75;
  bool _loadingUjian = true;
  bool _loadingRekap = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUjian();
  }

  Future<void> _loadUjian() async {
    setState(() {
      _loadingUjian = true;
      _error = null;
    });
    try {
      final rows = await Api.client
          .from('ujian')
          .select(
              '*,mata_pelajaran(nama,kkm),kelas(nama),jenis_ujian(nama)')
          .order('tanggal', ascending: false);
      if (!mounted) return;
      setState(() {
        _ujian = List<Map<String, dynamic>>.from(rows);
        _loadingUjian = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat ujian: $e';
        _loadingUjian = false;
      });
    }
  }

  Future<void> _pilih(Map<String, dynamic> u) async {
    setState(() {
      _selected = u;
      _peserta = [];
      _loadingRekap = true;
      _error = null;
    });
    final mapel = u['mata_pelajaran'];
    _kkm = mapel is Map && mapel['kkm'] != null
        ? double.tryParse('${mapel['kkm']}') ?? 75
        : 75.0;
    try {
      final rows = await Api.client.from('peserta_ujian').select(
          'id,status,nomor_peserta,finished_at,'
          'siswa!inner(nama,nis,kelas!inner(nama)),'
          'hasil_ujian(nilai,dinilai,pelanggaran)')
        .eq('ujian_id', u['id'])
        .order('id');
      if (!mounted) return;
      final list = List<Map<String, dynamic>>.from(rows)
          .map((r) {
        final m = Map<String, dynamic>.from(r);
        if (m['hasil_ujian'] is List && (m['hasil_ujian'] as List).isNotEmpty) {
          m['hasil_ujian'] = m['hasil_ujian'][0];
        } else if (m['hasil_ujian'] is List) {
          m['hasil_ujian'] = null;
        }
        return m;
      }).toList();
      setState(() {
        _peserta = list;
        _loadingRekap = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat rekap: $e\n(Isi/aktifkan kunci jawaban & kumpulkan peserta dulu)';
        _loadingRekap = false;
      });
    }
  }

  Map<String, List<Map<String, dynamic>>> get _byKelas {
    final out = <String, List<Map<String, dynamic>>>{};
    for (final p in _peserta) {
      final s = p['siswa'];
      final k = s is Map && s['kelas'] is Map
          ? '${(s['kelas'] as Map)['nama'] ?? '(tanpa kelas)'}'
          : '(tanpa kelas)';
      (out[k] = out[k] ?? []).add(p);
    }
    return out;
  }

  double? _nilai(Map<String, dynamic> p) {
    final h = p['hasil_ujian'];
    if (h is Map && h['nilai'] != null && h['dinilai'] != false) {
      return double.tryParse('${h['nilai']}');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Rekap Nilai per Rombel'),
        bottom: (_ujian.isEmpty || _loadingUjian)
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(64),
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
                  alignment: Alignment.center,
                  child: DropdownButton<String>(
                    isExpanded: true,
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    value: _selected?['id']?.toString(),
                    hint: const Text('— pilih ujian untuk direkap —',
                        style: TextStyle(fontSize: 13)),
                    items: _ujian
                        .map((u) => DropdownMenuItem(
                              value: u['id'].toString(),
                              child: Text(
                                  '${u['nama']}\n'
                                  '${u['mata_pelajaran'] is Map ? (u['mata_pelajaran'] as Map)['nama'] ?? '' : ''} • ${u['tanggal']?.toString().split('T').first}',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                  style: const TextStyle(fontSize: 13)),
                            ))
                        .toList(),
                    onChanged: (id) {
                      final u = _ujian.firstWhere(
                          (x) => x['id'].toString() == id);
                      _pilih(u);
                    },
                  ),
                ),
              ),
      ),
      body: _loadingUjian || _loadingRekap
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.danger, size: 40),
                      const SizedBox(height: 8),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: _selected != null
                              ? () => _pilih(_selected!)
                              : _loadUjian,
                          child: const Text('Coba Lagi')),
                    ]),
                  ),
                )
              : _selected == null
                  ? const Center(
                      child: Text(
                          'Pilih ujian untuk melihat rekap per rombel',
                          style: TextStyle(color: Colors.grey)))
                  : _buildRekap(),
    );
  }

  Widget _buildRekap() {
    final groups = _byKelas;
    if (groups.isEmpty) {
      return const Center(
          child: Text('Belum ada peserta terdaftar pada ujian ini\n(siswa masuk pakai token dulu)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey)));
    }
    final names = groups.keys.toList()..sort();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_selected!['nama']}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '${_selected!['mata_pelajaran'] is Map ? (_selected!['mata_pelajaran'] as Map)['nama'] ?? '—' : '—'} • KKM ${_kkm.toStringAsFixed(0)} • ${_peserta.length} peserta',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        for (final k in names) _kelasCard(k, groups[k]!),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _kelasCard(String kelas, List<Map<String, dynamic>> list) {
    final selesai = list.where((p) => p['status'] == 'selesai').toList();
    final nilaiList = selesai
        .map(_nilai)
        .whereType<double>()
        .toList();
    final rata = nilaiList.isEmpty
        ? 0.0
        : nilaiList.reduce((a, b) => a + b) / nilaiList.length;
    final tuntas = nilaiList.where((n) => n >= _kkm).length;
    final pct = nilaiList.isEmpty ? 0 : (tuntas * 100 / nilaiList.length).round();
    final maxN = nilaiList.isEmpty ? null : nilaiList.reduce((a, b) => a > b ? a : b);
    final minN = nilaiList.isEmpty ? null : nilaiList.reduce((a, b) => a < b ? a : b);
    final belum = list
        .where((p) => p['status'] != 'selesai' && p['status'] != 'mengikuti')
        .length;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const Border(),
        title: Row(
          children: [
            Expanded(
              child: Text('Rombel $kelas',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            Text('${list.length} peserta',
                style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _mini('Rata ${rata.toStringAsFixed(1)}',
                  nilaiList.isEmpty ? Colors.grey : AppTheme.primary),
              _mini('$pct% tuntas',
                  pct >= 70 ? AppTheme.secondary : AppTheme.danger),
              _mini('Selesai ${selesai.length}/${list.length}',
                  Colors.grey),
              if (belum > 0) _mini('Belum $belum', Colors.orange),
              if (maxN != null)
                _mini('Maks ${maxN.toStringAsFixed(0)}', Colors.grey),
              if (minN != null)
                _mini('Min ${minN.toStringAsFixed(0)}', Colors.grey),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Column(
              children: [
                for (final s in list)
                  _siswaRow(list.indexOf(s) + 1, s),
                if (nilaiList.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                        'Belum ada nilai keluar — cek: kunci jawaban sudah diisi? peserta sudah kumpul?',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 11.5, color: Colors.grey)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mini(String t, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12)),
      child: Text(t,
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _siswaRow(int no, Map<String, dynamic> p) {
    final s = (p['siswa'] as Map?) ?? const {};
    final h = (p['hasil_ujian'] as Map?) ;
    final nilai = _nilai(p);
    final status = '${p['status'] ?? 'belum'}';
    final pel = h?['pelanggaran'] is num
        ? (h!['pelanggaran'] as num).toInt()
        : 0;
    final nisTxt = (s['nis'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
              width: 24,
              child: Text('$no',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${s['nama'] ?? '?'}',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
                Text('$nisTxt${nisTxt.isNotEmpty ? ' • ' : ''}${_statusLabel(status)}',
                    style:
                        TextStyle(fontSize: 10.5, color: Colors.grey[600])),
              ],
            ),
          ),
          if (pel > 0)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text('⚠$pel',
                  style:
                      const TextStyle(fontSize: 10.5, color: AppTheme.danger)),
            ),
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: nilai == null
                    ? Colors.grey.withOpacity(0.12)
                    : (nilai >= _kkm ? AppTheme.secondary : AppTheme.danger)
                        .withOpacity(0.15),
                borderRadius: BorderRadius.circular(8)),
            child: Text(
              nilai != null
                  ? nilai.toStringAsFixed(0)
                  : status == 'selesai'
                      ? '…'
                      : '—',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: nilai == null
                      ? Colors.grey
                      : nilai >= _kkm
                          ? AppTheme.secondary
                          : AppTheme.danger),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String s) => switch (s) {
        'selesai' => 'selesai',
        'mengikuti' => 'sedang mengerjakan',
        'absen' => 'absen',
        'gagal' => 'tidak selesai',
        _ => 'belum masuk',
      };
}
