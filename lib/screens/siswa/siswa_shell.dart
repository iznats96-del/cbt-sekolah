import 'package:flutter/material.dart';

import '../../core/design.dart';
import '../../widgets/state_views.dart';
import '../home.dart';
import 'siswa_home_screen.dart';
import 'hasil_siswa_screen.dart';
import 'pengumuman_siswa_screen.dart';
import 'kartu_saya_screen.dart';

class SiswaShell extends StatefulWidget {
  const SiswaShell({super.key});

  @override
  State<SiswaShell> createState() => _SiswaShellState();
}

class _SiswaShellState extends State<SiswaShell> {
  int _index = 0;
  static const _titles = ['Beranda', 'Hasil', 'Info', 'Kartu'];

  static const _pages = [
    SiswaHomeScreen(),
    HasilSiswaScreen(),
    PengumumanSiswaScreen(),
    KartuSayaScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Cbt.paper,
        foregroundColor: Cbt.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
        ),
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 0, 9),
          child: Container(
            decoration: BoxDecoration(
              color: Cbt.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.school_rounded, color: Cbt.blue, size: 20),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _titles[_index],
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const Text(
              'Portal Siswa • SMK YP 79',
              style: TextStyle(fontSize: 10.5, color: Cbt.muted),
            ),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: LogoutButton(),
          ),
        ],
      ),
      body: ContentMaxWidth(child: _pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Beranda'),
          NavigationDestination(
              icon: Icon(Icons.assessment_outlined),
              selectedIcon: Icon(Icons.assessment),
              label: 'Hasil'),
          NavigationDestination(
              icon: Icon(Icons.campaign_outlined),
              selectedIcon: Icon(Icons.campaign),
              label: 'Info'),
          NavigationDestination(
              icon: Icon(Icons.qr_code_2_outlined),
              selectedIcon: Icon(Icons.qr_code_2),
              label: 'Kartu'),
        ],
      ),
    );
  }
}