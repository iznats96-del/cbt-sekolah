import 'package:flutter/material.dart';

import '../../core/design.dart';
import '../../widgets/dashboard_header.dart';
import '../../widgets/state_views.dart';
import '../home.dart';
import 'siswa_home_screen.dart';
import 'hasil_siswa_screen.dart';
import 'pengumuman_siswa_screen.dart';
import 'kartu_saya_screen.dart';
import '../../widgets/app_bottom_nav.dart';

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
    KartuSayaScreen(embedded: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DashboardHeader(
        title: _titles[_index].toUpperCase(),
        subtitle: 'Portal Siswa • SMK YP 79',
        actions: const [LogoutButton()],
      ),
      body: ContentMaxWidth(child: _pages[_index]),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _index,
        onChanged: (i) => setState(() => _index = i),
        items: const [
          NavItem(Icons.home_outlined, Icons.home, 'Beranda'),
          NavItem(Icons.assessment_outlined, Icons.assessment, 'Hasil'),
          NavItem(Icons.campaign_outlined, Icons.campaign, 'Info'),
          NavItem(Icons.qr_code_2_outlined, Icons.qr_code_2, 'Kartu'),
        ],
      ),
    );
  }
}