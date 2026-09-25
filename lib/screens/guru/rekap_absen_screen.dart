import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';

const _namaHari = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu'
];
const _namaBulan = [
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember'
];

String _dstr(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String _pendek(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

/// Rekap absen: HARIAN (per kelas + per jurusan + siapa belum),
/// MINGGUAN & BULANAN (per hari + total per kelas).
class RekapAbsenScreen extends StatefulWidget {
  const RekapAbsenScreen({super.key});

  @override
  State<RekapAbsenScreen> createState() => _RekapAbsenScreenState();
}

class _RekapAbsenScreenState extends State<RekapAbsenScreen> {
  List<Map<String, dynamic>> _siswa = [];
  // siswa_id -> {yyyy-MM-dd: status}
  Map<String, Map<String, String>> _hadir = {};
  bool _loading = true;
  String _q = '';
  int _mode = 0; // 0=harian, 1=mingguan, 2=bulanan
  DateTime _anchor = DateTime.now();

  DateTime get _day =>
      DateTime(_anchor.year, _anchor.month, _anchor.day);

  DateTime get _start {
    if (_mode == 1) return _day.subtract(Duration(days: _day.weekday - 1));
    if (_mode == 2) return DateTime(_day.year, _day.month, 1);
    return _day;
  }

  DateTime get _end {
    if (_mode == 1) return _start.add(const Duration(days: 6));
    if (_mode == 2) return DateTime(_day.year, _day.month + 1, 0);
    return _day;
  }

  String get _label {
    if (_mode == 1) return 'Minggu ${_pendek(_start)} – ${_pendek(_end)}';
    if (_mode == 2) return '${_namaBulan[_day.month - 1]} ${_day.year}';
    return '${_namaHari[_day.weekday - 1]}, ${_pendek(_day)}';
  }

  void _geser(int dir) {
    setState(() {
      if (_mode == 1) {
        _anchor = _anchor.add(Duration(days: 7 * dir));
      } else if (_mode == 2) {
        _anchor = DateTime(_anchor.year, _anchor.month + dir, 1);
      } else {
        _anchor = _anchor.add(Duration(days: dir));
      }
    });
    _load();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Future.wait([
        Api.client
            .from('siswa')
            .select('id,nama,nis,kelas(nama,jurusan(nama,singkatan))')
            .order('nama'),
        Api.client
            .from('kehadiran')
            .select('siswa_id,tanggal,status')
            .gte('tanggal', _dstr(_start))
            .lte('tanggal', _dstr(_end)),
      ]);
      if (!mounted) return;
      final had = <String, Map<String, String>>{};
      for (final r in (res[1] as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        (had['${m['siswa_id']}'] ??= {})['${m['tanggal']}'] =
            '${m['status'] ?? ''}';
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
    if (j is Map && '${j['singkatan'] ?? ''}'.isNotEmpty) {
      return '${j['singkatan']}';
    }
    return '';
  }

  String _stTgl(Map<String, dynamic> s, String tgl) =>
      _hadir['${s['id']}']?[tgl] ?? '';

  bool _isHadir(Map<String, dynamic> s) =>
      _stTgl(s, _dstr(_day)) == 'hadir';

  // ================= HARIAN =================

  List<Map<String, dynamic>> get _filtered {
    final q = _q.trim().toLowerCase();
    final list = q.isEmpty
        ? List<Map<String, dynamic>>.from(_siswa)
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

  Widget _ringkasan() {
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
          Text('Hadir $hadirAll/${_siswa.length} murid',
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in keys)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Text(k,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('${agg[k]![0]}/${agg[k]![1]} hadir',
                          style: const TextStyle(
                              fontSize: 11.5, color: Colors.grey)),
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
                    ? AppTheme.secondary.withValues(alpha: 0.15)
                    : AppTheme.accent.withValues(alpha: 0.15),
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
                  for (final s in belum) _row(s, false),
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
    final st = _stTgl(s, _dstr(_day));
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
                color: AppTheme.accent.withValues(alpha: 0.15),
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

  // ================= MINGGUAN / BULANAN =================

  List<DateTime> get _days {
    final out = <DateTime>[];
    for (var d = _start; !d.isAfter(_end); d = d.add(const Duration(days: 1))) {
      out.add(d);
    }
    return out;
  }

  int _hadirPada(DateTime d) {
    final t = _dstr(d);
    int n = 0;
    for (final s in _siswa) {
      if (_hadir['${s['id']}']?[t] == 'hadir') n++;
    }
    return n;
  }

  Widget _periode() {
    final days = _days;
    // total per kelas: catat hadir + murid unik
    final byKelas = <String, List<Map<String, dynamic>>>{};
    for (final s in _siswa) {
      final k = _kelasOf(s);
      (byKelas[k.isEmpty ? '(tanpa kelas)' : k] ??= []).add(s);
    }
    final kkeys = byKelas.keys.toList()..sort();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_label,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                      '${_days.length} hari • ${_siswa.length} murid',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final d in days) _hariRow(d),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 6, top: 4),
            child: Text('TOTAL PER KELAS',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1)),
          ),
          for (final k in kkeys) _kelasTotal(k, byKelas[k]!),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _hariRow(DateTime d) {
    final h = _hadirPada(d);
    final t = _siswa.length;
    final pct = t == 0 ? 0.0 : h / t;
    final isToday = _dstr(d) == _dstr(DateTime.now());
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_namaHari[d.weekday - 1]}, ${_pendek(d)}${isToday ? ' • hari ini' : ''}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: isToday ? AppTheme.primary : null),
                  ),
                ),
                Text('$h/$t',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13.5)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(
                    pct >= 0.8
                        ? AppTheme.secondary
                        : pct >= 0.4
                            ? AppTheme.accent
                            : AppTheme.danger),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kelasTotal(String nama, List<Map<String, dynamic>> list) {
    int catat = 0;
    final unik = <String>{};
    final days = _days.map(_dstr).toSet();
    for (final s in list) {
      final m = _hadir['${s['id']}'] ?? {};
      for (final e in m.entries) {
        if (e.value == 'hadir' && days.contains(e.key)) {
          catat++;
          unik.add('${s['id']}');
        }
      }
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
          child: Text('${unik.length}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                  fontSize: 13)),
        ),
        title: Text(nama,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
        subtitle: Text('$catat catat hadir • ${unik.length}/${list.length} murid pernah hadir',
            style: const TextStyle(fontSize: 11.5)),
      ),
    );
  }

  // ================= SHELL =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: const Text('Rekap Absen')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // mode + navigasi tanggal
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    children: [
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(
                              value: 0,
                              label: Text('Harian'),
                              icon: Icon(Icons.today, size: 16)),
                          ButtonSegment(
                              value: 1,
                              label: Text('Mingguan'),
                              icon: Icon(Icons.date_range, size: 16)),
                          ButtonSegment(
                              value: 2,
                              label: Text('Bulanan'),
                              icon: Icon(Icons.calendar_month, size: 16)),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (s) {
                          setState(() => _mode = s.first);
                          _load();
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: () => _geser(-1),
                          ),
                          Expanded(
                            child: Text(_label,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: () => _geser(1),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() => _anchor = DateTime.now());
                              _load();
                            },
                            child: const Text('Hari ini'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_mode == 0)
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
                if (_mode == 0) _ringkasan(),
                Expanded(
                    child: _mode == 0 ? _daftarKelas() : _periode()),
              ],
            ),
    );
  }
}
