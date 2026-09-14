import 'package:flutter/material.dart';

import '../../services/api.dart';
import '../home.dart';
import 'data_master_screen.dart';
import 'bank_soal_screen.dart';
import 'ujian_list_screen.dart';
import 'hasil_screen.dart';
import 'pengumuman_screen.dart';
import 'pengaturan_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  static const _titles = [
    'Beranda',
    'Data Master',
    'Bank Soal',
    'Ujian',
    'Pengumuman',
    'Pengaturan',
  ];

  static const _pages = [
    _AdminHome(),
    DataMasterScreen(),
    BankSoalScreen(),
    UjianListScreen(),
    PengumumanScreen(),
    PengaturanScreen(),
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
  const _AdminHome();

  Future<void> _loadProfile(BuildContext context) async {
    // placeholder - ringkasan akan ditampilkan
  }

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
                const Text('Selamat datang, Administrator',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Kelola data ujian, bank soal, dan peserta dari menu di bawah.',
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
          childAspectRatio: 1.4,
          children: const [
            _FeatureCard(icon: Icons.people_outline, label: 'Siswa', color: Color(0xFF1A6DB4)),
            _FeatureCard(icon: Icons.person_outline, label: 'Guru', color: Color(0xFF2E9B8F)),
            _FeatureCard(icon: Icons.quiz_outlined, label: 'Bank Soal', color: Color(0xFFF4A940)),
            _FeatureCard(icon: Icons.assignment_outlined, label: 'Ujian', color: Color(0xFFD9534F)),
          ],
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _FeatureCard({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withOpacity(0.1),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {},
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}