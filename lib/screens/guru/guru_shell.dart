import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../../widgets/dashboard_header.dart';
import '../../widgets/state_views.dart';
import '../home.dart';
import 'bank_soal_screen.dart';
import 'jadwal_screen.dart';
import 'nilai_screen.dart';
import 'scan_absen_screen.dart';
import '../../widgets/app_bottom_nav.dart';

class GuruShell extends StatefulWidget {
  const GuruShell({super.key});

  @override
  State<GuruShell> createState() => _GuruShellState();
}

class _GuruShellState extends State<GuruShell> {
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    const pages = [
      _GuruHome(),
      BankSoalScreen(),
      JadwalScreen(),
      NilaiScreen(),
      ScanAbsenScreen(),
    ];
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _index,
        onChanged: _go,
        items: const [
          NavItem(Icons.home_outlined, Icons.home, 'Beranda'),
          NavItem(Icons.quiz_outlined, Icons.quiz, 'Soal'),
          NavItem(Icons.event_outlined, Icons.event, 'Jadwal'),
          NavItem(Icons.grade_outlined, Icons.grade, 'Nilai'),
          NavItem(Icons.qr_code_scanner_outlined, Icons.qr_code_scanner, 'Absen'),
        ],
      ),
    );
  }
}

class _GuruHome extends StatefulWidget {
  const _GuruHome();

  @override
  State<_GuruHome> createState() => _GuruHomeState();
}

class _GuruHomeState extends State<_GuruHome> {
  Map<String, dynamic> _stats = {};
  List<dynamic> _jadwal = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api.fallbackGetApi('/api/guru/dashboard');
      if (!mounted) return;
      setState(() {
        _stats = res is Map ? Map<String, dynamic>.from(res['stats'] ?? {}) : {};
        final j = res is Map ? res['jadwal_hari_ini'] : null;
        _jadwal = j is List ? j : const [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    void push(Widget page) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    return Scaffold(
      appBar: DashboardHeader(
           title: 'CBT GURU',
           subtitle: 'Kelola soal, jadwal, nilai & absensi',
           stats: [
             ('mapel', '${_stats['mapel_diampu'] ?? 0}'),
             ('ujian aktif', '${_stats['ujian_aktif'] ?? 0}'),
             ('esai', '${_stats['esai_menunggu_koreksi'] ?? 0}'),
           ],
           actions: const [LogoutButton()],
         ),
      body: ContentMaxWidth(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [AppTheme.secondary, AppTheme.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Selamat datang, Guru',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    SizedBox(height: 6),
                    Text('Kelola bank soal, jadwal ujian, nilai, dan absensi Anda.',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _GuruRingkasan(
              stats: _stats,
              jadwal: _jadwal,
              loading: _loading,
              refresh: _load,
            ),
            const SizedBox(height: 16),
            _TodayFocus(jadwal: _jadwal),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, c) {
              final cols = (c.maxWidth / 200).floor().clamp(2, 4);
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.5,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  _MiniCard(
                      icon: Icons.quiz_outlined,
                      label: 'Bank Soal',
                      color: AppTheme.primary,
                      onTap: () => push(const BankSoalScreen())),
                  _MiniCard(
                      icon: Icons.event_outlined,
                      label: 'Jadwal Ujian',
                      color: AppTheme.secondary,
                      onTap: () => push(const JadwalScreen())),
                  _MiniCard(
                      icon: Icons.grade_outlined,
                      label: 'Rekap Nilai',
                      color: AppTheme.accent,
                      onTap: () => push(const NilaiScreen())),
                  _MiniCard(
                      icon: Icons.fact_check_outlined,
                      label: 'Absen QR',
                      color: AppTheme.danger,
                      onTap: () => push(const ScanAbsenScreen())),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _GuruRingkasan extends StatelessWidget {
  final Map<String, dynamic> stats;
  final List<dynamic> jadwal;
  final bool loading;
  final VoidCallback refresh;
  const _GuruRingkasan({
    required this.stats,
    required this.jadwal,
    required this.loading,
    required this.refresh,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    String val(String k) => '${stats[k] ?? 0}';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights, size: 18, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text('Ringkasan mengajar',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                IconButton(
                  onPressed: refresh,
                  tooltip: 'Muat ulang',
                  icon: const Icon(Icons.refresh, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _stat('Mapel diampu', val('mapel_diampu'), AppTheme.primary),
                const SizedBox(width: 8),
                _stat('Ujian aktif', val('ujian_aktif'), AppTheme.secondary),
                const SizedBox(width: 8),
                _stat('Esai menunggu', val('esai_menunggu_koreksi'), AppTheme.accent),
              ],
            ),
            if (jadwal.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('${jadwal.length} ujian terjadwal hari ini',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 3),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
            ],
          ),
        ),
      );
}

class _TodayFocus extends StatelessWidget {
  final List<dynamic> jadwal;
  const _TodayFocus({this.jadwal = const []});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Fokus hari ini',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 5),
        Text(
          jadwal.isEmpty
              ? 'Siapkan soal, cek jadwal, lalu pantau nilai dan absensi dari shortcut di bawah.'
              : '${jadwal.length} ujian hari ini — cek jadwal & pantau nilai di bawah.',
          style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
        ),
      ]),
    );
  }
}

class _MiniCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MiniCard(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: color.withValues(alpha: 0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
