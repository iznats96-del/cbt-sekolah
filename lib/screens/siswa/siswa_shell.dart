import 'package:flutter/material.dart';

import '../home.dart';
import 'siswa_home_screen.dart';
import 'hasil_siswa_screen.dart';
import 'pengumuman_siswa_screen.dart';

class SiswaShell extends StatefulWidget {
  const SiswaShell({super.key});

  @override
  State<SiswaShell> createState() => _SiswaShellState();
}

class _SiswaShellState extends State<SiswaShell> {
  int _index = 0;
  static const _titles = ['Beranda', 'Hasil', 'Info'];

  static const _pages = [
    SiswaHomeScreen(),
    HasilSiswaScreen(),
    PengumumanSiswaScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: SlideAppBar(
        title: _titles[_index],
        actions: const [LogoutButton()],
      ),
      body: PageView(
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (index) => setState(() => _index = index),
        children: _pages,
      ),
      bottomNavigationBar: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(context, 0, Icons.home_rounded, 'Beranda'),
              _buildNavItem(context, 1, Icons.assessment_rounded, 'Hasil'),
              _buildNavItem(context, 2, Icons.campaign_rounded, 'Info'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, String label) {
    final isSelected = _index == index;
    return GestureDetector(
      onTap: () {
        setState(() => _index = index);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) {
                return ScaleTransition(scale: anim, child: RotationTransition(turns: anim, child: child));
              },
              child: Icon(
                isSelected ? icon : icon.outline,
                key: ValueKey(isSelected),
                size: 24,
                color: isSelected ? AppTheme.primary : Colors.grey[400],
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              defaultStyle: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
              ),
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? AppTheme.primary : Colors.grey[400],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}