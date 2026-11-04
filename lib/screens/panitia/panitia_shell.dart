import 'package:flutter/material.dart';

import '../home.dart';
import 'monitoring_ujian_screen.dart';
import 'peserta_ujian_screen.dart';
import 'rekap_panitia_screen.dart';
import 'foto_siswa_screen.dart';

class PanitiaShell extends StatefulWidget {
  const PanitiaShell({super.key});

  @override
  State<PanitiaShell> createState() => _PanitiaShellState();
}

class _PanitiaShellState extends State<PanitiaShell> {
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    const pages = [
      _PanitiaHome(),
      MonitoringUjianScreen(),
      PesertaUjianScreen(),
      RekapPanitiaScreen(),
      FotoSiswaScreen(),
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
              icon: Icon(Icons.monitor_heart_outlined),
              selectedIcon: Icon(Icons.monitor_heart),
              label: 'Monitoring'),
          NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'Peserta'),
          NavigationDestination(
              icon: Icon(Icons.assessment_outlined),
              selectedIcon: Icon(Icons.assessment),
              label: 'Rekap'),
          NavigationDestination(
              icon: Icon(Icons.photo_camera_outlined),
              selectedIcon: Icon(Icons.photo_camera),
              label: 'Foto'),
        ],
      ),
    );
  }
}

class _PanitiaHome extends StatelessWidget {
  const _PanitiaHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Panitia'),
        actions: const [LogoutButton()],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A6DB4), Color(0xFF2E9B8F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selamat Datang, Panitia',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Monitor pelaksanaan ujian secara real-time',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: [
                      _MenuCard(
                        icon: Icons.monitor_heart,
                        title: 'Monitoring Ujian',
                        subtitle: 'Pantau progres peserta',
                        color: const Color(0xFFE3F2FD),
                        onTap: () {}, // handled by nav bar
                      ),
                      _MenuCard(
                        icon: Icons.people,
                        title: 'Daftar Peserta',
                        subtitle: 'Cek kehadiran & status',
                        color: const Color(0xFFE8F5E9),
                        onTap: () {},
                      ),
                      _MenuCard(
                        icon: Icons.assessment,
                        title: 'Rekap Hasil',
                        subtitle: 'Lihat nilai & statistik',
                        color: const Color(0xFFFFF3E0),
                        onTap: () {},
                      ),
                      _MenuCard(
                        icon: Icons.qr_code_scanner,
                        title: 'Scan Absen',
                        subtitle: 'Verifikasi peserta',
                        color: const Color(0xFFF3E5F5),
                        onTap: () {
                          Navigator.of(context).pushNamed('/panitia/scan');
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: const Color(0xFF1A6DB4)),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}