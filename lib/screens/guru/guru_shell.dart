import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../widgets/state_views.dart';
import '../home.dart';
import 'bank_soal_screen.dart';
import 'jadwal_screen.dart';
import 'nilai_screen.dart';
import 'scan_absen_screen.dart';

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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Beranda'),
          NavigationDestination(
              icon: Icon(Icons.quiz_outlined),
              selectedIcon: Icon(Icons.quiz),
              label: 'Soal'),
          NavigationDestination(
              icon: Icon(Icons.event_outlined),
              selectedIcon: Icon(Icons.event),
              label: 'Jadwal'),
          NavigationDestination(
              icon: Icon(Icons.grade_outlined),
              selectedIcon: Icon(Icons.grade),
              label: 'Nilai'),
          NavigationDestination(
              icon: Icon(Icons.qr_code_scanner_outlined),
              selectedIcon: Icon(Icons.qr_code_scanner),
              label: 'Absen'),
        ],
      ),
    );
  }
}

class _GuruHome extends StatelessWidget {
  const _GuruHome();

  @override
  Widget build(BuildContext context) {
    void push(Widget page) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    return Scaffold(
      appBar: AppBar(
        title: const Text('CBT Guru'),
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
            _TodayFocus(),
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

class _TodayFocus extends StatelessWidget {
  const _TodayFocus();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Fokus hari ini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        SizedBox(height: 5),
        Text('Siapkan soal, cek jadwal, lalu pantau nilai dan absensi dari shortcut di bawah.', style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4)),
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
