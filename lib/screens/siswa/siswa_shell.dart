import 'package:flutter/material.dart';

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