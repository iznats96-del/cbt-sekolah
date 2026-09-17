import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';
import '../../services/api.dart';
import '../../services/auth_service.dart';
import '../../widgets/modern_widgets.dart';
import '../admin/admin_shell.dart';
import '../siswa/siswa_shell.dart';
import '../guru/guru_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _queueNote;
  int _attempt = 0;
  
  late AnimationController _iconController;
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(duration: const Duration(seconds: 3), vsync: this);
    _pulseController = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);
    _scaleAnimation = Tween(begin: 1.0, end: 1.05).animate(CurvedAnimation(
      parent: _iconController,
      curve: Curves.easeInOut,
    ));
    _pulseAnimation = Tween(begin: 0.8, end: 1.2).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _iconController.repeat(reverse: true);
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _iconController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final pass = _pass.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Email atau NIS dan password wajib diisi.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _queueNote = null;
      _attempt = 0;
    });
    try {
      String loginEmail = email;
      if (!email.contains('@')) {
        loginEmail = '${email.toLowerCase()}@cbt.local';
      }
      final res = await _loginResilient(loginEmail, pass);
      if (res.user != null) {
        Api.setRole(res.user!.userMetadata?['role'] as String?);
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
      if (!mounted) return;
      setState(() {
        _error = _parseAuthError(e);
        _loading = false;
        _queueNote = null;
      });
    }
  }

  /// Login dengan antrian otomatis menghadapi rate-limit server (HTTP 429).
  Future<AuthResponse> _loginResilient(String email, String pass) async {
    const maxTries = 60;
    Object? lastErr;
    for (_attempt = 1; _attempt <= maxTries; _attempt++) {
      try {
        final res = await _auth.loginEmail(email, pass);
        return res;
      } on AuthException catch (e) {
        lastErr = e;
        final rateLimited = _isRateLimit(e);
        if (!rateLimited) rethrow;
        final wait = 2 + (_attempt % 5).toDouble();
        if (mounted) {
          setState(() => _queueNote =
              'Server lagi ramai — kamu antrian ke-$_attempt. '
              'Tunggu ${(wait * 1000).round()}ms, JANGAN tutup aplikasi.');
        }
        await Future.delayed(
            Duration(milliseconds: (wait * 1000).round()));
      } on PostgrestException catch (e) {
        lastErr = e;
        if (e.code != '429') rethrow;
        if (mounted) {
          setState(() => _queueNote = 'Antrian server ($_attempt)... jangan tutup aplikasi.');
        }
        await Future.delayed(Duration(seconds: 2 + (_attempt % 4)));
      }
    }
    throw lastErr ?? Exception('Gagal login setelah banyak percobaan');
  }

  bool _isRateLimit(AuthException e) {
    final s = '${e.statusCode ?? ''} ${e.message}';
    return s.contains('429') ||
        s.toLowerCase().contains('rate limit') ||
        s.toLowerCase().contains('too many');
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
      body: AnimatedBackground(
        colors: [const Color(0xFF1A6DB4), const Color(0xFF2E9B8F), const Color(0xFFF4A940)],
        duration: const Duration(seconds: 8),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo with pulse animation
                  FadeIn(
                    animation: CurvedAnimation(parent: _pulseController, curve: Curves.elasticOut),
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(Icons.school_outlined, size: 64, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // App title
                  AnimatedOpacity(
                    opacity: _loading ? 0.7 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Text(AppConfig.appName,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                offset: const Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ])),
                  ),
                  const SizedBox(height: 8),
                  const Text('Silakan masuk untuk memulai ujian',
                      style: TextStyle(color: Colors.white70, fontSize: 15)),
                  const SizedBox(height: 40),
                  // Glassmorphism card
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: GlassCard(
                      backgroundColor: Colors.white.withOpacity(0.15),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Email/NIS input with icon animation
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Email atau NIS',
                              prefixIcon: AnimatedRotation(
                                turns: _loading ? 0.5 : 0,
                                duration: const Duration(milliseconds: 500),
                                child: const Icon(Icons.person_outline, color: Colors.white),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.15),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              hintMaxLines: 1,
                              hintText: 'Masukkan email atau NIS Anda',
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Password input with visibility toggle
                          TextField(
                            controller: _pass,
                            obscureText: _obscure,
                            onSubmitted: (_) => !_loading ? _login() : null,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline, color: Colors.white),
                              suffixIcon: IconButton(
                                icon: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  transitionBuilder: (child, anim) => RotationTransition(
                                    turns: anim,
                                    child: child,
                                  ),
                                  child: Icon(
                                    _obscure ? Icons.visibility : Icons.visibility_off,
                                    key: ValueKey(_obscure),
                                    color: Colors.white,
                                  ),
                                ),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.15),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Queue progress indicator
                          if (_queueNote != null && _loading) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: LinearProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          backgroundColor: Colors.white.withOpacity(0.2),
                                          minHeight: 4,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: AppTheme.secondary.withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.queue, size: 16, color: Colors.white),
                                            const SizedBox(width: 6),
                                            Text('$_attempt', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(_queueNote!,
                                      style: const TextStyle(
                                          fontSize: 13, color: Colors.white70)),
                                ],
                              ),
                            ),
                          ],
                          // Error message
                          if (_error != null && !_loading) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.danger.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          // Modern login button with animated ripple
                          ModernButton(
                            text: _loading ? 'Memproses...' : 'MASUK SEKARANG',
                            onPressed: _loading ? null : _login,
                            icon: _loading ? null : Icons.login_rounded,
                            isLoading: _loading,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Opacity(
                    opacity: 0.8,
                    child: Text(
                      'Gunakan akun yang diberikan operator sekolah',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
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

