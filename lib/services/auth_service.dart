import 'package:supabase_flutter/supabase_flutter.dart';
import 'api.dart';

class AuthService {
  final _client = Api.client;

  Future<AuthResponse> loginEmail(String email, String password) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> registerEmail(String email, String password,
      {String nama = '', String role = 'siswa'}) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'role': role, 'nama': nama},
    );
    if (res.user != null) {
      await _upsertProfile(res.user!, nama: nama, role: role);
    }
    return res;
  }

  Future<void> _upsertProfile(User user,
      {String nama = '', String role = 'siswa'}) async {
    await _client.from('profiles').upsert({
      'id': user.id,
      'email_show': user.email,
      'role': role,
      'nama': nama,
    });
  }

  Future<void> logout() async {
    await _client.auth.signOut();
  }

  /// Membuat akun siswa dengan NIS dipetakan ke email internal.
  Future<AuthResponse> createStudentAccount({
    required String nis,
    required String nama,
    required String password,
  }) async {
    final email = '${nis.toLowerCase()}@cbt.local';
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'role': 'siswa', 'nama': nama},
    );
    if (res.user != null) {
      await _client.from('profiles').upsert({
        'id': res.user!.id,
        'email_show': email,
        'role': 'siswa',
        'nama': nama,
        'nis': nis,
      });
    }
    return res;
  }

  Future<void> linkStudentProfile(User user, String nis) async {
    await _client.from('profiles').update({'nis': nis}).eq('id', user.id);
  }
}