import 'package:flutter/material.dart';

import '../home.dart';
import 'bank_soal_screen.dart';
import 'jadwal_screen.dart';
import 'nilai_screen.dart';
import 'presensi_screen.dart';
import 'pengumuman_screen.dart';

class GuruShell extends StatefulWidget {
  const GuruShell({super.key});

  @override
  State<GuruShell> createState() => _GuruShellState();
}

class _GuruShellState extends State<GuruShell> {
  int _index = 0;
  static const _titles = ['Guru', 'Soal', 'Jadwal', 'Nilai'];

  static const _pages = [
    _GuruHome(),
    BankSoalScreen(),
    JadwalScreen(),
    NilaiScreen(),
    PresensiScreen(),
    PengumumanScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: const [LogoutButton()],
      ),
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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
        ],
      ),
    );
  }
}

class _GuruHome extends StatelessWidget {
  const _GuruHome();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Selamat datang, Guru',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Kelola bank soal dan jadwal ujian Anda.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.5,
          children: [
            _MiniCard(icon: Icons.quiz_outlined, label: 'Bank Soal', color: const Color(0xFF1A6DB4)),
            _MiniCard(icon: Icons.event_outlined, label: 'Jadwal Ujian', color: const Color(0xFF2E9B8F)),
            _MiniCard(icon: Icons.grade_outlined, label: 'Nilai', color: const Color(0xFFF4A940)),
            _MiniCard(icon: Icons.fact_check_outlined, label: 'Presensi', color: const Color(0xFFD9534F)),
          ],
        ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniCard({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.1),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}