import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../widgets/state_views.dart';
import '../home.dart';
import '../shared/update_screen.dart';
import 'user_management_screen.dart';
import '../../widgets/dashboard_header.dart';

class PengaturanScreen extends StatelessWidget {
  const PengaturanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: DashboardHeader(
        title: 'SETELAN',
        subtitle: 'Pengaturan aplikasi & sekolah',
        actions: const [LogoutButton()],
      ),
      body: ContentMaxWidth(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('PENGATURAN',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
          ),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Profil'),
                  subtitle: const Text('Nama, peran, kontak'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _comingSoon(context, 'Profil'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings),
                  title: const Text('User Management'),
                  subtitle: const Text('Buat akun guru & panitia, password 79xxxx'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const UserManagementScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.school_outlined),
                  title: const Text('Profil Sekolah'),
                  subtitle: const Text('Data umum sekolah'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _comingSoon(context, 'Profil Sekolah'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.storage_outlined),
                  title: const Text('Database'),
                  subtitle: const Text('Backup & restore'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _comingSoon(context, 'Database'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.update),
                  title: const Text('Update Aplikasi'),
                  subtitle: const Text('Periksa & pasang versi terbaru'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const UpdateScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Tentang CBT Sekolah'),
                  subtitle: const Text('Versi 1.1.0'),
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context, String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name — fitur menyusul')),
    );
  }
}
