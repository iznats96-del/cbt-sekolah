import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../services/api.dart';
import 'auth/login_screen.dart';
import 'home.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    // cek sesi aktif
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      _go(const LoginScreen());
      return;
    }

    final ok = await Api.init();
    debugPrint('CBT-DIAG splash ok=$ok role=${Api.role} user=${Supabase.instance.client.auth.currentUser?.email}');
    if (!mounted) return;

    // patch: role kosong berarti baru daftar -> paksa ke login
    if (!ok || Api.role == null) {
      await Supabase.instance.client.auth.signOut();
      _go(const LoginScreen());
      return;
    }

    // Jika role masih null, coba ambil dari profiles table
    if (Api.role == null) {
      try {
        final p = await Api.currentProfile();
        final profileRole = p?['role'] as String?;
        if (profileRole != null) {
          Api.setRole(profileRole);
        }
      } catch (_) {}
    }

    _go(const HomeScreen());
  }

  void _go(Widget page) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1E40AF), Color(0xFF2563EB), Color(0xFF0EA5A4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x331E3A66),
                      blurRadius: 22,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Image.asset('assets/images/logo_yp.png', width: 72, height: 72, errorBuilder: (_, __, ___) => const Icon(Icons.school_outlined, size: 48, color: Color(0xFF1A6DB4))),
              ),
              const SizedBox(height: 16),
              Text(
                AppConfig.appName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Computer Based Test',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 22),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}