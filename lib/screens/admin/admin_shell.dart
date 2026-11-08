import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../home.dart';
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

class _AdminHome extends StatelessWidget {
  final void Function(int index) go;
  const _AdminHome({required this.go});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CBT Sekolah'),
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
                    colors: [AppTheme.primary, AppTheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Selamat datang, Administrator',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    SizedBox(height: 6),
                    Text(
                        'Kelola data ujian, bank soal, dan peserta dari menu di bawah.',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ControlCenter(),
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
                  _FeatureCard(
                      icon: Icons.people_outline,
                      label: 'Siswa',
                      color: AppTheme.primary,
                      onTap: () => go(1)),
                  _FeatureCard(
                      icon: Icons.person_outline,
                      label: 'Guru',
                      color: AppTheme.secondary,
                      onTap: () => go(1)),
                  _FeatureCard(
                      icon: Icons.quiz_outlined,
                      label: 'Bank Soal',
                      color: AppTheme.accent,
                      onTap: () => go(2)),
                  _FeatureCard(
                      icon: Icons.assignment_outlined,
                      label: 'Ujian',
                      color: AppTheme.danger,
                      onTap: () => go(3)),
                  _FeatureCard(
                      icon: Icons.insert_chart_outlined,
                      label: 'Rekap Nilai',
                      color: const Color(0xFF7C4DBC),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const RekapNilaiScreen()))),
                  _FeatureCard(
                      icon: Icons.badge_outlined,
                      label: 'Daftar Akun + Password',
                      color: const Color(0xFF2F6F4F),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const DaftarAkunScreen()))),
                  _FeatureCard(
                      icon: Icons.person_add_outlined,
                      label: 'Akun Guru & Panitia',
                      color: const Color(0xFFB25C00),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const UserManagementScreen()))),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
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
