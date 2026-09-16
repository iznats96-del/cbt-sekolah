import 'package:flutter/material.dart';

import '../../widgets/modern_shell.dart';
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
  static const _titles = ['Guru', 'Soal', 'Jadwal', 'Nilai', 'Presensi'];

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
              _buildNavItem(context, 1, Icons.quiz_rounded, 'Soal'),
              _buildNavItem(context, 2, Icons.event_rounded, 'Jadwal'),
              _buildNavItem(context, 3, Icons.grade_rounded, 'Nilai'),
              _buildNavItem(context, 4, Icons.check_circle_rounded, 'Presensi'),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: '_main_fab',
        onPressed: () {},
        backgroundColor: AppTheme.primary,
        elevation: 6,
        icon: const Icon(Icons.add),
        label: Text('Buat ${_getIndexTitle()}'),
      ),
    );
  }

  String _getIndexTitle() {
    switch (_index) {
      case 0: return 'Pengumuman';
      case 1: return 'Soal';
      case 2: return 'Jadwal';
      case 3: return 'Nilai';
      case 4: return 'Presensi';
      default: return '';
    }
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
            _MiniCard(
              onTap: () => setState(() => _index = 0),
              icon: Icons.quiz_outlined, 
              label: 'Bank Soal', 
              color: const Color(0xFF1A6DB4)),
            _MiniCard(
              onTap: () => setState(() => _index = 2),
              icon: Icons.event_outlined, 
              label: 'Jadwal Ujian', 
              color: const Color(0xFF2E9B8F)),
            _MiniCard(
              onTap: () => setState(() => _index = 3),
              icon: Icons.grade_outlined, 
              label: 'Nilai', 
              color: const Color(0xFFF4A940)),
            _MiniCard(
              onTap: () => setState(() => _index = 4),
              icon: Icons.fact_check_outlined, 
              label: 'Presensi', 
              color: const Color(0xFFD9534F)),
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
  final VoidCallback? onTap;
  const _MiniCard({
    required this.icon, 
    required this.label, 
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        color: color.withOpacity(0.1),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}