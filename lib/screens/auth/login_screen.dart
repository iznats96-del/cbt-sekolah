import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';
import '../../services/api.dart';
import '../../services/auth_service.dart';
import '../../services/hybrid_api.dart';
import '../admin/admin_shell.dart';
import '../siswa/siswa_shell.dart';
import '../guru/guru_shell.dart';
import '../panitia/panitia_shell.dart';

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
  String? _queueNote; // info antrian rate-limit
  int _attempt = 0;

  final _auth = AuthService();

  Future<void> _login() async {
    final email = _email.text.trim();
    final pass = _pass.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Email/username dan password wajib diisi.');
      return;
    }
    // dukung login pakai NIS -> map ke email internal
    String loginEmail = email;
    if (!email.contains('@')) {
      loginEmail = '${email.toLowerCase()}@cbt.local';
    }
    setState(() {
      _loading = true;
      _error = null;
      _queueNote = null;
      _attempt = 0;
    });
    try {
      // MODE FALLBACK TOTAL: skip Supabase SDK entirely, langsung ke fallback server
      if (AppConfig.supabaseDisabled) {
        final fallbackRes = await HybridApi.login(loginEmail, pass);
        final source = fallbackRes['source'] as String?;
        final user = fallbackRes['user'];
        if (source == 'fallback' && user is Map<String, dynamic>) {
          try {
            final p = await Api.currentProfile();
            final profileRole = p?['role'] as String?;
            final metaRole = user['role'] as String?;
            Api.setRole(profileRole ?? metaRole);
          } catch (_) {
            Api.setRole(user['role'] as String?);
          }
          Api.forceFallback();
          final ok = await Api.init();
          if (!mounted) return;
          if (!ok || Api.role == null) {
            setState(() {
              _loading = false;
              _error = 'Akun fallback belum memiliki peran. Hubungi operator sekolah.';
            });
            return;
          }
          _goToRole();
          return;
        }
        throw Exception('Fallback login failed');
      }

      final res = await _loginResilient(loginEmail, pass);
      if (res.user != null) {
        // Ambil role dari BOTH sources: GoTrue metadata + profiles table
        // Prefer profiles (lebih fresh, bisa di-update admin via UI)
        final metadataRole = res.user!.userMetadata?['role'] as String?;
        try {
          final p = await Api.currentProfile();
          final profileRole = p?['role'] as String?;
          // Gunakan profileRole jika ada, kalau gak metadataRole
          final effectiveRole = profileRole ?? metadataRole;
          Api.setRole(effectiveRole);
          // Jika profiles kosong, buat profile default
          if (p == null) {
            await _auth.registerEmail(loginEmail, pass,
                nama: res.user!.userMetadata?['nama'] as String? ?? '',
                role: effectiveRole ?? 'siswa');
          }
        } catch (_) {
          // Fallback ke metadata saja
          Api.setRole(metadataRole);
        }
        final ok = await Api.init();
        if (!ok || Api.role == null) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _error = 'Akun belum memiliki peran. Hubungi operator sekolah.';
          });
          return;
        }
      } else {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Login gagal. Periksa email/username dan password.';
        });
        return;
      }
      if (!mounted) return;
      _goToRole();
    } catch (e) {
      // Supabase auth gagal — try local fallback
      debugPrint('LoginScreen: Supabase login failed, trying fallback...');
      try {
        final fallbackRes = await HybridApi.login(loginEmail, pass);
        final source = fallbackRes['source'] as String?;
        final user = fallbackRes['user'];
        if (source == 'fallback' && user is Map<String, dynamic>) {
          // Fallback juga ambil role dari profiles
          try {
            final p = await Api.currentProfile();
            final profileRole = p?['role'] as String?;
            final metaRole = user['role'] as String?;
            Api.setRole(profileRole ?? metaRole);
          } catch (_) {
            Api.setRole(user['role'] as String?);
          }
          await Api.init();
          if (!mounted) return;
          _goToRole();
          return;
        }
      } catch (fallbackErr) {
        debugPrint('LoginScreen: Fallback login also failed: $fallbackErr');
      }
      if (!mounted) return;
      setState(() {
        _error = _parseAuthError(e);
        _loading = false;
        _queueNote = null;
      });
    }
  }

  /// Login dengan antrian otomatis menghadapi rate-limit server (HTTP 429).
  /// Total waktu tunggu maks ~4 menit (sesuai perilaku bot yang lolos 384/384).
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
        if (!rateLimited) rethrow; // error nyata (password salah dll) langsung tampil
        final wait = 2 + (_attempt % 5).toDouble(); // 2-6 dtk acak
        if (mounted) {
          setState(() => _queueNote =
              'Server lagi ramai — kamu antrian ke-$_attempt. '
              'Tunggu ${wait.toStringAsFixed(0)} detik, JANGAN tutup aplikasi.');
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
      case 'panitia':
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const PanitiaShell()));
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
            colors: [Color(0xFF1E40AF), Color(0xFF2563EB), Color(0xFF0EA5A4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(right: -70, top: -90, child: _glow(230)),
              Positioned(left: -80, bottom: -100, child: _glow(270)),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0x331E3A66),
                                blurRadius: 22,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/logo_yp.png',
                            width: 66,
                            height: 66,
                            errorBuilder: (_, __, ___) => const Icon(
                                Icons.school_outlined,
                                size: 44,
                                color: Color(0xFF2563EB)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppConfig.appName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Silakan masuk untuk memulai ujian',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 26),
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0x2E0F172A),
                                blurRadius: 26,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                style: const TextStyle(fontSize: 14),
                                decoration: _input('Email atau NIS',
                                    Icons.person_outline),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _pass,
                                obscureText: _obscure,
                                autocorrect: false,
                                enableSuggestions: false,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _login(),
                                style: const TextStyle(fontSize: 14),
                                decoration: _input('Password', Icons.lock_outline).copyWith(
                                  suffixIconConstraints: const BoxConstraints(
                                      minWidth: 44, maxHeight: 44),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: const Color(0xFF94A3B8),
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                  ),
                                ),
                              ),
                              if (_queueNote != null) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F1FF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF2563EB)),
                                      ),
                                      const SizedBox(width: 9),
                                      Expanded(
                                        child: Text(
                                          _queueNote!,
                                          style: const TextStyle(
                                              fontSize: 11.5,
                                              color: Color(0xFF1E40AF)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (_error != null) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF1F2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline,
                                          size: 17, color: Color(0xFFEF4444)),
                                      const SizedBox(width: 9),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFFB91C1C)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 22),
                              SizedBox(
                                height: 50,
                                child: FilledButton.icon(
                                  onPressed: _loading ? null : _login,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: _loading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.login, size: 19),
                                  label: Text(
                                    _loading ? 'Memeriksa akun…' : 'MASUK',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Gunakan akun yang diberikan operator sekolah',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _input(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFF2563EB), size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFF),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE7EDFA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE7EDFA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.6),
        ),
      );

  Widget _glow(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.06),
        ),
      );
}
