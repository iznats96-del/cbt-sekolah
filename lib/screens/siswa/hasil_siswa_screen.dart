import 'package:flutter/material.dart';

import '../../services/api.dart';
import '../../widgets/state_views.dart';

/// Hasil Siswa — rekap per mapel.
/// Satu kartu = satu mapel, nilai = rata-rata dari nilai ujian yang benar-benar
/// diperoleh siswa, status dibandingkan dengan KKM mapel.

const _bg = Color(0xFFF4F7FF);
const _card = Colors.white;
const _navy = Color(0xFF101F3C);
const _navySoft = Color(0xFF3B4B6B);
const _muted = Color(0xFF8A97B1);
const _blue = Color(0xFF2563EB);
const _blueLight = Color(0xFFE8F1FF);
const _purple = Color(0xFF7C4DFF);
const _green = Color(0xFF22C55E);
const _red = Color(0xFFEF4444);
const _track = Color(0xFFE7EDFA);

num? _num(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  return num.tryParse(v.toString());
}

int _nilaiBulat(dynamic v) => _num(v)?.round() ?? 0;

class HasilSiswaScreen extends StatefulWidget {
  const HasilSiswaScreen({super.key});

  @override
  State<HasilSiswaScreen> createState() => _HasilSiswaScreenState();
}

class _HasilSiswaScreenState extends State<HasilSiswaScreen> {
  List<Map<String, dynamic>> _rows = [];
  Map<String, double> _kkmByMapel = {};
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
      final results = await Future.wait([
        Api.routerRpc('my_hasil'),
        Api.routerSelect('mata_pelajaran', select: 'id,nama,kkm')
            .catchError((_) => <Map<String, dynamic>>[]),
      ]);
      final rows = results[0] as List;
      final mapels = results[1] as List;
      final kkm = <String, double>{};
      for (final m in mapels) {
        final mm = m as Map;
        final nama = '${mm['nama'] ?? ''}'.trim();
        final nilai = _num(mm['kkm']);
        if (nama.isNotEmpty && nilai != null) kkm[nama] = nilai.toDouble();
      }
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(rows);
        _kkmByMapel = kkm;
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

  Map<String, List<Map<String, dynamic>>> get _groups {
    final out = <String, List<Map<String, dynamic>>>{};
    for (final r in _rows) {
      final nama = '${r['mapel'] ?? '-'}'.trim();
      out.putIfAbsent(nama.isEmpty ? '-' : nama, () => []).add(r);
    }
    return out;
  }

  int _rata(List<Map<String, dynamic>> rows) {
    final vals = rows
        .where((r) => _num(r['nilai']) != null)
        .map((r) => _nilaiBulat(r['nilai']))
        .toList();
    if (vals.isEmpty) return 0;
    return (vals.fold<int>(0, (a, b) => a + b) / vals.length).round();
  }

  double _kkm(String mapel) => _kkmByMapel[mapel] ?? 75;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: CircularProgressIndicator(color: _blue, strokeWidth: 3),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: _bg,
        body: ErrorState(message: _error!, onRetry: _load),
      );
    }
    if (_rows.isEmpty) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.assignment_outlined, size: 64, color: _blue),
                SizedBox(height: 16),
                Text('Belum ada hasil ujian',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700, color: _navy)),
                SizedBox(height: 8),
                Text(
                  'Nilaimu akan muncul di sini setelah kamu mengumpulkan ujian.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: _muted),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final groups = _groups;
    final names = groups.keys.toList()..sort();
    final bernilai = _rows.where((r) => _num(r['nilai']) != null).toList();
    final rata = _rata(bernilai);
    final rataKkm = names.isEmpty
        ? 75.0
        : names.fold<double>(0, (s, n) => s + _kkm(n)) / names.length;
    final tuntas =
        names.where((n) => _rata(groups[n]!) >= _kkm(n)).length;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: _blue,
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
            children: [
              _Neumorphic(
                child: _HeroCard(
                  rata: rata,
                  kkm: rataKkm.round(),
                  total: names.length,
                  tuntas: tuntas,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _Neumorphic(
                      child: _StatCard(
                        icon: Icons.menu_book_rounded,
                        color: _blue,
                        value: '${names.length}',
                        label: 'Mapel',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Neumorphic(
                      child: _StatCard(
                        icon: Icons.assignment_outlined,
                        color: _purple,
                        value: '${_rows.length}',
                        label: 'Ujian',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Neumorphic(
                      child: _StatCard(
                        icon: Icons.check,
                        color: _green,
                        value: '$tuntas',
                        label: 'Tuntas',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  'NILAI PER MAPEL',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _muted,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              for (final nama in names) ...[
                _MapelCard(
                  mapel: nama,
                  rows: groups[nama]!,
                  rata: _rata(groups[nama]!),
                  kkm: _kkm(nama),
                ),
                const SizedBox(height: 14),
              ],
              _InfoCard(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wrapper kartu neumorphic: putih, radius besar, bayang lembut menyebar.
class _Neumorphic extends StatelessWidget {
  final Widget child;
  const _Neumorphic({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.07),
            blurRadius: 26,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.9),
            blurRadius: 4,
            offset: const Offset(-3, -3),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Hero ringkasan keseluruhan.
class _HeroCard extends StatelessWidget {
  final int rata;
  final int kkm;
  final int total;
  final int tuntas;

  const _HeroCard({
    required this.rata,
    required this.kkm,
    required this.total,
    required this.tuntas,
  });

  @override
  Widget build(BuildContext context) {
    final perluLatihan = rata < kkm;
    final warnaStatus = perluLatihan ? _red : _green;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    _BarIcon(),
                    SizedBox(width: 10),
                    Text(
                      'Rata-Rata Semua Mapel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '$rata',
                  style: const TextStyle(
                    fontSize: 68,
                    fontWeight: FontWeight.w800,
                    color: _navy,
                    height: 1,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: warnaStatus.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        perluLatihan
                            ? Icons.warning_rounded
                            : Icons.check_circle_rounded,
                        size: 17,
                        color: warnaStatus,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        perluLatihan ? 'Perlu Latihan' : 'Tuntas',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: warnaStatus,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _ProgressRing(rata: rata, kkm: kkm),
        ],
      ),
    );
  }
}

class _BarIcon extends StatelessWidget {
  const _BarIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _bar(10, _blue.withValues(alpha: 0.55)),
          _bar(17, _blue.withValues(alpha: 0.75)),
          _bar(26, _blue),
        ],
      ),
    );
  }

  Widget _bar(double h, Color c) => Container(
        width: 7,
        height: h,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(4),
        ),
      );
}

class _ProgressRing extends StatelessWidget {
  final int rata;
  final int kkm;
  const _ProgressRing({required this.rata, required this.kkm});

  @override
  Widget build(BuildContext context) {
    final value = (rata / 100).clamp(0.0, 1.0).toDouble();
    final warna = rata < kkm ? _red : _green;
    return SizedBox(
      width: 142,
      height: 142,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 142,
            height: 142,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 14,
              backgroundColor: _track,
              valueColor: AlwaysStoppedAnimation(warna),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$rata',
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '/ 100',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _navySoft,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                      height: 1),
                ),
                const SizedBox(height: 5),
                Text(label,
                    style: const TextStyle(fontSize: 13, color: _navySoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu satu mapel: rata-rata + status, bisa dibuka untuk lihat daftar ujian.
class _MapelCard extends StatelessWidget {
  final String mapel;
  final List<Map<String, dynamic>> rows;
  final int rata;
  final double kkm;

  const _MapelCard({
    required this.mapel,
    required this.rows,
    required this.rata,
    required this.kkm,
  });

  @override
  Widget build(BuildContext context) {
    final tuntas = rata >= kkm;
    final warna = tuntas ? _green : _red;
    final sorted = List<Map<String, dynamic>>.from(rows)
      ..sort((a, b) => '${b['tanggal'] ?? ''}'.compareTo('${a['tanggal'] ?? ''}'));

    return _Neumorphic(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(18, 12, 14, 12),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        iconColor: _blue,
        collapsedIconColor: _muted,
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _blueLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.menu_book_rounded, color: _blue, size: 24),
        ),
        title: Text(
          mapel,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800, color: _navy),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Text(
                '${rows.length} ujian • KKM ${kkm.round()}',
                style: const TextStyle(fontSize: 11.5, color: _muted),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: warna.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  tuntas ? 'Tuntas' : 'Perlu Latihan',
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700, color: warna),
                ),
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$rata',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800, color: warna),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
        children: [
          const Divider(height: 1, color: _track),
          for (final r in sorted) _UjianRow(data: r, kkm: kkm),
        ],
      ),
    );
  }
}

class _UjianRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final double kkm;
  const _UjianRow({required this.data, required this.kkm});

  @override
  Widget build(BuildContext context) {
    final nilai = _nilaiBulat(data['nilai']);
    final warna = nilai >= kkm ? _green : _red;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _blueLight,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.assignment_turned_in_outlined,
                size: 19, color: _blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data['ujian'] ?? '-'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _navy),
                ),
                const SizedBox(height: 3),
                Text(
                  '${data['tanggal'] ?? ''}  •  B ${data['benar'] ?? 0} / S ${data['salah'] ?? 0} / K ${data['kosong'] ?? 0}',
                  style: const TextStyle(fontSize: 10.5, color: _muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('$nilai',
              style: TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w800, color: warna)),
        ],
      ),
    );
  }
}

/// Kartu Informasi biru muda dengan dekorasi lengkungan.
class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFDDE8FF),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              bottom: -70,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 60, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                        color: _blue, shape: BoxShape.circle),
                    child: const Icon(Icons.tips_and_updates_rounded,
                        color: Colors.white, size: 27),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informasi',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _navy),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Nilai per mapel adalah rata-rata dari seluruh ujian '
                          'mapel tersebut. Ketuk kartu mapel untuk melihat '
                          'nilai tiap ujian.',
                          style: TextStyle(
                              fontSize: 13,
                              color: _navySoft,
                              height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
