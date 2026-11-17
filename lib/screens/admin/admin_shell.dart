import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/design.dart';
import '../../services/api.dart';
import '../home.dart';
import '../../widgets/cetak_kartu_helper.dart';
import '../../widgets/state_views.dart';
import 'data_master_screen.dart';
import 'bank_soal_screen.dart';
import 'ujian_list_screen.dart';
import 'pengumuman_screen.dart';
import 'daftar_akun_screen.dart';
import 'user_management_screen.dart';
import '../shared/rekap_nilai_screen.dart';
import 'pengaturan_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final pages = [
      _AdminHome(go: _go),
      const DataMasterScreen(),
      const BankSoalScreen(),
      const UjianListScreen(),
      const PengumumanScreen(),
      const PengaturanScreen(),
    ];
    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Beranda'),
          NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder),
              label: 'Master'),
          NavigationDestination(
              icon: Icon(Icons.quiz_outlined),
              selectedIcon: Icon(Icons.quiz),
              label: 'Soal'),
          NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: 'Ujian'),
          NavigationDestination(
              icon: Icon(Icons.campaign_outlined),
              selectedIcon: Icon(Icons.campaign),
              label: 'Info'),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Setelan'),
        ],
      ),
    );
  }
}

class _AdminHome extends StatefulWidget {
  final void Function(int index) go;
  const _AdminHome({required this.go});

  @override
  State<_AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<_AdminHome> {
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api.fallbackGetApi('/api/admin/dashboard');
      if (!mounted) return;
      setState(() {
        _stats = res is Map ? Map<String, dynamic>.from(res['stats'] ?? res) : {};
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cbt.paper,
      appBar: AppBar(
        backgroundColor: Cbt.paper,
        foregroundColor: Cbt.ink,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CBT Sekolah', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text('Pusat kendali ujian', style: Cbt.caption),
          ],
        ),
        actions: const [LogoutButton()],
      ),
      body: ContentMaxWidth(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              // Header ringkas
              Cbt.card(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(color: Cbt.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.admin_panel_settings_outlined, color: Cbt.blue, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Selamat datang, Administrator',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Cbt.ink)),
                          SizedBox(height: 3),
                          Text('Kelola siswa, soal, dan jalannya ujian dari satu tempat.', style: Cbt.caption),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Statistik (dari /api/admin/dashboard)
              _loading
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator(color: Cbt.blue)),
                    )
                  : GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 9,
                      crossAxisSpacing: 9,
                      childAspectRatio: 2,
                      children: [
                        _stat('Siswa', _stats['total_siswa'], Icons.people_outline, Cbt.blue),
                        _stat('Guru', _stats['total_guru'], Icons.person_outline, Cbt.teal),
                        _stat('Kelas', _stats['total_kelas'], Icons.school_outlined, Cbt.amber),
                        _stat('Bank soal', _stats['total_soal'], Icons.quiz_outlined, Cbt.blue),
                      ],
                    ),
              const SizedBox(height: 16),
              _ControlCenter(),
              const SizedBox(height: 16),
              Cbt.label('AKSES CEPAT'),
              const SizedBox(height: 10),
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
                    _FeatureCard(icon: Icons.people_outline, label: 'Siswa', color: Cbt.blue, onTap: () => widget.go(1)),
                    _FeatureCard(icon: Icons.person_outline, label: 'Guru', color: Cbt.teal, onTap: () => widget.go(1)),
                    _FeatureCard(icon: Icons.quiz_outlined, label: 'Bank Soal', color: Cbt.amber, onTap: () => widget.go(2)),
                    _FeatureCard(icon: Icons.assignment_outlined, label: 'Ujian', color: Cbt.red, onTap: () => widget.go(3)),
                    _FeatureCard(
                      icon: Icons.print_outlined,
                      label: 'Cetak Kartu',
                      color: Cbt.blue,
                      onTap: () => pilihDanCetakKartu(context),
                    ),
                    _FeatureCard(
                      icon: Icons.insert_chart_outlined,
                      label: 'Rekap Nilai',
                      color: Cbt.blue,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RekapNilaiScreen())),
                    ),
                    _FeatureCard(
                      icon: Icons.badge_outlined,
                      label: 'Daftar Akun + Password',
                      color: Cbt.teal,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DaftarAkunScreen())),
                    ),
                    _FeatureCard(
                      icon: Icons.person_add_outlined,
                      label: 'Akun Guru & Panitia',
                      color: Cbt.amber,
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UserManagementScreen())),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, dynamic value, IconData icon, Color color) => Cbt.card(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 17, color: color),
                const Spacer(),
                Text('$value', style: Cbt.display.copyWith(fontSize: 24, color: Cbt.ink)),
              ],
            ),
            const SizedBox(height: 5),
            Text(label, style: Cbt.caption),
          ],
        ),
      );
}

class _ControlCenter extends StatelessWidget {
  const _ControlCenter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.dashboard_customize_outlined, color: AppTheme.primary),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Pusat kendali', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 3),
                Text('Akses cepat untuk persiapan ujian hari ini', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          const _ChecklistRow(Icons.people_outline, 'Pastikan data siswa dan kelas sudah lengkap'),
          const _ChecklistRow(Icons.quiz_outlined, 'Cek soal dan kunci jawaban sebelum mengaktifkan ujian'),
          const _ChecklistRow(Icons.assignment_turned_in_outlined, 'Pantau rekap nilai setelah ujian selesai'),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ChecklistRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(children: [
        Icon(icon, size: 18, color: AppTheme.secondary),
        const SizedBox(width: 9),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
      ]),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _FeatureCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

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
