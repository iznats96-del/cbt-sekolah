import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../screens/auth/login_screen.dart';
import '../screens/siswa/pelaksanaan_screen.dart';
import '../screens/admin/admin_shell.dart';

/// Entry khusus untuk Widget Preview di VS Code.
/// Tidak dipakai untuk build APK — hanya untuk `F5 > Widget Preview`.
/// Cara pakai: Run and Debug > "CBT - Widget Preview" atau
/// Flutter Widget Preview panel (Flutter 3.32+ / Dart-Code).
void main() => runApp(const PreviewApp());

class PreviewApp extends StatelessWidget {
  const PreviewApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _PreviewMenu(),
    );
  }
}

class _PreviewMenu extends StatefulWidget {
  const _PreviewMenu();
  @override
  State<_PreviewMenu> createState() => _PreviewMenuState();
}

class _PreviewMenuState extends State<_PreviewMenu> {
  int idx = 0;
  final List<Widget> pages = const [
    LoginScreen(),
    AdminShell(),
    // Pelaksanaan butuh pesertaId asli, jadi tampilkan mock card saja
    _FakePelaksanaanPreview(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Widget Preview — CBT Sekolah')),
      body: pages[idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => setState(() => idx = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.login), label: 'Login'),
          NavigationDestination(icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
          NavigationDestination(icon: Icon(Icons.quiz), label: 'Ujian'),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _PreviewCard({required this.title, required this.child});
  Widget get widget => child;
  @override
  Widget build(BuildContext context) => child;
}

class _FakePelaksanaanPreview extends StatelessWidget {
  const _FakePelaksanaanPreview();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Text('PREVIEW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                ),
                const SizedBox(height: 8),
                const Text('PelaksanaanScreen', style: TextStyle(fontWeight: FontWeight.bold)),
                const Text('Butuh pesertaId live dari Supabase, jadi preview ini hanya mock header/timer.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
