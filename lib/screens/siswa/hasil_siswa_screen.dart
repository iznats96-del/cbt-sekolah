import 'package:flutter/material.dart';

import '../../services/api.dart';
import '../../widgets/state_views.dart';

/// ─────────────────────────────────────────────────────────────
/// Hasil Siswa — Pastel Neumorphic (rujukan desain user)
/// ─────────────────────────────────────────────────────────────
/// Karakter visual:
///  • Latar biru sangat muda (#F4F7FF), kartu putih radius ~24 dgn
///    bayang lembut menyebar (neumorphic).
///  • Tipografi navy tebal (#101F3C), aksen biru (#2563EB), ungu,
///    hijau, merah; pill status merah muda.
///  • Hero = angka besar + progress cincin "17 / 100" + badge status.
///  • Kartu stat 3 kolom + kartu Riwayat + kartu Informasi biru muda.
/// ─────────────────────────────────────────────────────────────

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
const _redPill = Color(0xFFFFE4E6);
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
      final rows = await Api.routerRpc('my_hasil');
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
                    style: TextStyle(fontSize: 13, color: _muted)),
              ],
            ),
          ),
        ),
      );
    }

    final dinilaiCount = _rows.where((r) => r['dinilai'] == true).length;
    final tuntas = _rows
        .where((r) => r['dinilai'] == true && _nilaiBulat(r['nilai']) >= 75)
        .length;
    final bernilai = _rows.where((r) => r['nilai'] != null).toList();
    final rata = bernilai.isEmpty
        ? 0
        : (bernilai.fold<int>(0, (s, r) => s + _nilaiBulat(r['nilai'])) /
                bernilai.length)
            .round();

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
                  total: _rows.length,
                  dinilai: dinilaiCount,
                  tuntas: tuntas,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _Neumorphic(
                      child: _StatCard(
                        icon: Icons.check,
                        color: _blue,
                        value: '${_rows.length}',
                        label: 'Ujian',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Neumorphic(
                      child: _StatCard(
                        icon: Icons.bar_chart_rounded,
                        color: _purple,
                        value: '$dinilaiCount',
                        label: 'Dinilai',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Neumorphic(
                      child: _StatCard(
                        icon: Icons.schedule,
                        color: _green,
                        value: '$tuntas',
                        label: 'Tuntas',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
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

/// Hero: judul + angka besar + badge status + cincin progres merah.
class _HeroCard extends StatelessWidget {
  final int rata;
  final int total;
  final int dinilai;
  final int tuntas;

  const _HeroCard({
    required this.rata,
    required this.total,
    required this.dinilai,
    required this.tuntas,
  });

  @override
  Widget build(BuildContext context) {
    final perluLatihan = rata < 75;
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
                      'Rata-Rata Nilai',
                      style: TextStyle(
                        fontSize: 17,
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
                    color: _redPill,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_rounded,
                          size: 17, color: warnaStatus),
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
          _ProgressRing(rata: rata),
        ],
      ),
    );
  }
}

/// Ikon tiga batang naik (bar chart) — pertama pendek, terakhir tertinggi.
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

/// Cincin progres: track abu muda + busur merah sesuai nilai, tengah "n / 100".
class _ProgressRing extends StatelessWidget {
  final int rata;
  const _ProgressRing({required this.rata});

  @override
  Widget build(BuildContext context) {
    final value = (rata / 100).clamp(0.0, 1.0).toDouble();
    final warna = rata < 75 ? _red : _green;
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

/// Kartu stat kecil: lingkaran ikon warna + angka + label.
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
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: const TextStyle(fontSize: 13, color: _navySoft),
                ),
              ],
            ),
          ),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Informasi',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _navy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Hasil ujian ini adalah hasil akhir dari ujian yang telah Anda kerjakan.',
                          style: TextStyle(
                            fontSize: 13,
                            color: _navySoft.withValues(alpha: 0.85),
                            height: 1.5,
                          ),
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