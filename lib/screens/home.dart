import 'package:flutter/material.dart';

import '../services/api.dart';
import 'admin/admin_shell.dart';
import 'guru/guru_shell.dart';
import 'siswa/siswa_shell.dart';
import 'panitia/panitia_shell.dart';
import 'auth/login_screen.dart';
import '../../services/hybrid_api.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    switch (Api.role) {
      case 'admin':
        return const AdminShell();
      case 'guru':
        return const GuruShell();
      case 'panitia':
        return const PanitiaShell();
      case 'siswa':
      default:
        return const SiswaShell();
    }
  }
}

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.logout),
      tooltip: 'Keluar',
      onPressed: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Keluar'),
            content: const Text('Yakin ingin keluar dari aplikasi?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Batal')),
              FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Keluar')),
            ],
          ),
        );
        if (ok == true && context.mounted) {
          await HybridApi.logout();
          Api.setRole(null);
          if (context.mounted) {
            Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()));
          }
        }
      },
    );
  }
}