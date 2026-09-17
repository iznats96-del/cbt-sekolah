import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../../widgets/modern_widgets.dart';

/// REKAP NILAI TERPADU (GURU) — dikelompokkan per Mata Pelajaran.
class RekapNilaiFullScreen extends StatefulWidget {
  const RekapNilaiFullScreen({super.key});

  @override
  State<RekapNilaiFullScreen> createState() => _RekapNilaiFullScreenState();
}

class _RekapNilaiFullScreenState extends State<RekapNilaiFullScreen> {
  List<Map<String, dynamic>> _ujianList = [];
  List<Map<String, dynamic>> _hasilList = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final ujian = await Api.client
          .from('ujian')
          .select('*,mata_pelajaran(nama),kelas(nama)')
          .order('created_at', ascending: false);
      final hasil = await Api.client
          .from('hasil_ujian')
          .select('peserta_ujian_id,nilai,jumlah_benar,jumlah_salah,jumlah_kosong,dinilai,'
              'peserta_ujian(ujian_id,siswa(nama,nis))');
      if (!mounted) return;
      setState(() {
        _ujianList = List<Map<String, dynamic>>.from(ujian);
        _hasilList = List<Map<String, dynamic>>.from(hasil);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context: context, message: 'Gagal memuat rekap: $e', type: ToastType.error);
    }
  }

  String _mapelOf(String? ujianId) {
    final u = _ujianList.firstWhere(
      (x) => x['id'] == ujianId,
      orElse: () => <String, dynamic>{},
    );
    final mp = u['mata_pelajaran'];
    return (mp is Map ? '${mp['nama']}' : 'Tanpa Mapel');
  }

  String _kelasOf(String? ujianId) {
    final u = _ujianList.firstWhere(
      (x) => x['id'] == ujianId,
      orElse: () => <String, dynamic>{},
    );
    final k = u['kelas'];
    return (k is Map ? '${k['nama']}' : '-');
  }

  String _namaSiswa(Map<String, dynamic> h) {
    final p = h['peserta_ujian'];
    if (p is Map && p['siswa'] is Map) return '${(p['siswa'] as Map)['nama'] ?? '?'}';
    return 'Peserta';
  }

  String _nisSiswa(Map<String, dynamic> h) {
    final p = h['peserta_ujian'];
    if (p is Map && p['siswa'] is Map) return '${(p['siswa'] as Map)['nis'] ?? '-'}';
    return '-';
  }

  String? _ujianIdOf(Map<String, dynamic> h) {
    final p = h['peserta_ujian'];
    return (p is Map) ? p['ujian_id']?.toString() : null;
  }

  List<Map<String, dynamic>> get _filtered {
    if (_query.trim().isEmpty) return _hasilList;
    final q = _query.toLowerCase();
    return _hasilList.where((h) {
      final mapel = _mapelOf(_ujianIdOf(h)).toLowerCase();
      final nama = _namaSiswa(h).toLowerCase();
      final nis = _nisSiswa(h).toLowerCase();
      return mapel.contains(q) || nama.contains(q) || nis.contains(q);
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> get _byMapel {
    final out = <String, List<Map<String, dynamic>>>{};
    for (final h in _filtered) {
      final m = _mapelOf(_ujianIdOf(h));
      (out[m] ??= []).add(h);
    }
    return out;
  }

  Future<void> _exportCSV() async {
    final buf = StringBuffer('Mapel,Kelas,Ujian,Siswa,NIS,Nilai,Benar,Salah,Kosong,Dinilai\n');
    for (final h in _filtered) {
      final uid = _ujianIdOf(h);
      final row = [
        _mapelOf(uid),
        _kelasOf(uid),
        _ujianList.firstWhere((x) => x['id'] == uid, orElse: () => {'nama': ''})['nama'],
        _namaSiswa(h),
        _nisSiswa(h),
        h['nilai']?.toString() ?? '-',
        '${h['jumlah_benar'] ?? 0}',
        '${h['jumlah_salah'] ?? 0}',
        '${h['jumlah_kosong'] ?? 0}',
        '${h['dinilai'] ?? false}',
      ];
      buf.writeln(row.map((c) => '"${'$c'.replaceAll('"', '')}"').join(','));
    }
    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (mounted) {
      showToast(context: context, message: 'CSV tersalin ke clipboard', type: ToastType.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Rekap Nilai Terpadu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export CSV',
            onPressed: _loading ? null : _exportCSV,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Cari mapel / nama / NIS...',
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
                Expanded(child: _buildBody()),
              ],
            ),
    );
  }

  Widget _buildBody() {
    final groups = _byMapel;
    if (groups.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Belum ada nilai.\nHasil muncul setelah siswa mengumpulkan & guru mengoreksi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    final keys = groups.keys.toList()..sort();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final m in keys) _mapelCard(m, groups[m]!),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _mapelCard(String mapel, List<Map<String, dynamic>> list) {
    final nilai = list
        .map((h) => (h['nilai'] as num?)?.toDouble())
        .whereType<double>()
        .toList();
    final rata = nilai.isEmpty ? 0.0 : nilai.reduce((a, b) => a + b) / nilai.length;
    final maxN = nilai.isEmpty ? 0.0 : nilai.reduce((a, b) => a > b ? a : b);
    final minN = nilai.isEmpty ? 0.0 : nilai.reduce((a, b) => a < b ? a : b);
    final lulus = nilai.where((n) => n >= 75).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const Border(),
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withOpacity(0.12),
          child: const Icon(Icons.menu_book_outlined, color: AppTheme.primary, size: 20),
        ),
        title: Text('$mapel',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
        subtitle: Text(
          '${list.length} siswa • rata ${rata.toStringAsFixed(1)} • lulus $lulus/${nilai.length}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Row(
            children: [
              _stat('Rata', rata.toStringAsFixed(1), AppTheme.primary),
              const SizedBox(width: 8),
              _stat('Tertinggi', maxN.toStringAsFixed(0), AppTheme.secondary),
              const SizedBox(width: 8),
              _stat('Terendah', minN.toStringAsFixed(0), AppTheme.danger),
            ],
          ),
          const SizedBox(height: 8),
          for (final h in list) _row(h),
        ],
      ),
    );
  }

  Widget _stat(String label, String val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(val, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
            Text(label, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _row(Map<String, dynamic> h) {
    final nilai = (h['nilai'] as num?)?.toDouble();
    final lulus = nilai != null && nilai >= 75;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_namaSiswa(h),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text('${_nisSiswa(h)} • ${_kelasOf(_ujianIdOf(h))}',
                    style: TextStyle(fontSize: 10.5, color: Colors.grey[600])),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (lulus ? AppTheme.secondary : AppTheme.danger).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              nilai == null ? '—' : nilai.toStringAsFixed(0),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: lulus ? AppTheme.secondary : AppTheme.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
