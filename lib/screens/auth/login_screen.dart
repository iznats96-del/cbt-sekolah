import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../services/api.dart';
import '../../services/auth_service.dart';
import '../admin/admin_shell.dart';
import '../siswa/siswa_shell.dart';
import '../guru/guru_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  final _auth = AuthService();

  Future<void> _login() async {
    final email = _email.text.trim();
    final pass = _pass.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Email/username dan password wajib diisi.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // dukung login pakai NIS -> map ke email internal
      String loginEmail = email;
      if (!email.contains('@')) {
        loginEmail = '${email.toLowerCase()}@cbt.local';
      }
      final res = await _auth.loginEmail(loginEmail, pass);
      if (res.user != null) {
        Api.setRole(res.user!.userMetadata?['role'] as String?);
        // pastikan profil default
        try {
          final p = await Api.currentProfile();
          if (p == null) {
            await _auth.registerEmail(loginEmail, pass,
                nama: res.user!.userMetadata?['nama'] as String? ?? '',
                role: res.user!.userMetadata?['role'] as String? ?? 'siswa');
          }
        } catch (_) {}
        await Api.init();
      }
      if (!mounted) return;
      _goToRole();
    } catch (e) {
      setState(() {
        _error = _parseAuthError(e);
        _loading = false;
      });
    }
  }

  String _parseAuthError(Object e) {
    final s = e.toString();
    if (s.contains('Invalid login credentials') ||
        s.contains('invalid_credentials')) {
      return 'Email/username atau password salah.';
    }
    if (s.contains('Email not confirmed') || s.contains('email_not_confirmed')) {
      return 'Email belum dikonfirmasi. Silakan cek email, atau minta admin mengaktifkan akun.';
    }
    return 'Gagal masuk: $e';
  }

  void _goToRole() {
    switch (Api.role) {
      case 'admin':
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AdminShell()));
      case 'guru':
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const GuruShell()));
      case 'siswa':
      default:
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SiswaShell()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A6DB4), Color(0xFF2E9B8F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.school_outlined, size: 64, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(AppConfig.appName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Silakan masuk untuk memulai ujian',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 32),
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email atau NIS',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _pass,
                            obscureText: _obscure,
                            onSubmitted: (_) => _login(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure
                                    ? Icons.visibility
                                    : Icons.visibility_off),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(_error!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 13)),
                          ],
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _loading ? null : _login,
                            child: _loading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2))
                                : const Text('MASUK',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Gunakan akun yang diberikan operator sekolah',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}