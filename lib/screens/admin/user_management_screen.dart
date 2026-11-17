import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../home.dart';
import '../../widgets/state_views.dart';
import '../../widgets/dashboard_header.dart';

/// Manajemen Akun Guru & Panitia: buat/list/reset password/hapus.
/// Password auto format 79xxxx. Login pakai email atau @cbt.local.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<Map<String, dynamic>> _guruList = [];
  List<Map<String, dynamic>> _panitiaList = [];
  bool _loading = true;
  String? _error;
  bool _creating = false;

  final _namaCtrl = TextEditingController();
  final _nipCtrl = TextEditingController();
  final _jabatanCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String _rolePilih = 'guru';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _nipCtrl.dispose();
    _jabatanCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await Api.client
          .from('profiles')
          .select('id,nama,email_show,pw_default,nip,role')
          .inFilter('role', ['guru', 'panitia'])
          .order('nama');
      if (!mounted) return;
      setState(() {
        _guruList = rows.where((r) => r['role'] == 'guru').toList();
        _panitiaList = rows.where((r) => r['role'] == 'panitia').toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat: $e';
        _loading = false;
      });
    }
  }


  static String _cleanEmail(String s) {
    final t = s.replaceAll(RegExp('[^a-z0-9]+'), '.');
    return t.isEmpty ? 'guru' : t;
  }

  Future<void> _create() async {
    final nama = _namaCtrl.text.trim();
    if (nama.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nama wajib diisi')));
      return;
    }
    setState(() => _creating = true);
    try {
      // RPC jalan di fallback server (pemegang service key) -> create auth user
      // Supabase via GoTrue admin API + profiles + tabel guru.
      final res = await Api.client.rpc('admin_buat_akun', params: {
        'p_role': _rolePilih,
        'p_nama': nama,
        'p_email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        'p_nip': _rolePilih == 'guru'
            ? (_nipCtrl.text.trim().isEmpty ? null : _nipCtrl.text.trim())
            : null,
        'p_jabatan': _jabatanCtrl.text.trim().isEmpty
            ? null
            : _jabatanCtrl.text.trim(),
      });
      final m = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
      if (!mounted) return;
      final email = '${m['email'] ?? ''}';
      final pw = '${m['pw'] ?? ''}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Akun "$nama" ($_rolePilih) dibuat.\nLogin: $email  •  Password: $pw'),
          backgroundColor: AppTheme.secondary,
          duration: const Duration(seconds: 8)));
      _resetForm();
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal: $e'),
              backgroundColor: AppTheme.danger,
              duration: const Duration(seconds: 6)));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _resetForm() {
    _namaCtrl.clear();
    _nipCtrl.clear();
    _jabatanCtrl.clear();
    _emailCtrl.clear();
    _rolePilih = 'guru';
  }

  Future<void> _resetPw(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Reset password ${p['nama'] ?? ''}?'),
        content: const Text(
            'Password baru format 79xxxx akan dibuat (sinkron ke auth user Supabase). Password lama tidak berlaku.',
            style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Reset')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await Api.client.rpc('admin_reset_pw', params: {'p_id': p['id']});
      final m = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Password baru ${p['nama'] ?? ''}: ${m['pw'] ?? '?'}'),
          backgroundColor: AppTheme.secondary,
          duration: const Duration(seconds: 5)));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal: $e'),
              backgroundColor: AppTheme.danger,
              duration: const Duration(seconds: 5)));
    }
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Hapus akun ${p['nama'] ?? ''}?'),
        content: Text(
            'Akun login ${p['email_show'] ?? ''} akan dihapus permanen dari Supabase.',
            style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      // Server-side: hapus dari auth.users + profiles + guru (service key)
      await Api.client.rpc('admin_hapus_akun', params: {'p_id': p['id']});
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal hapus: $e'),
              backgroundColor: AppTheme.danger,
              duration: const Duration(seconds: 5)));
    }
  }

  Widget _akunRow(Map<String, dynamic> p, {bool isGuru = true}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor:
              (isGuru ? AppTheme.secondary : AppTheme.accent).withValues(alpha: 0.15),
          child: Icon(
              isGuru ? Icons.school_outlined : Icons.gavel_outlined,
              size: 18,
              color: isGuru ? AppTheme.secondary : AppTheme.accent),
        ),
        title: Text('${p['nama'] ?? ''}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text('${p['email_show'] ?? '-'}',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            if (isGuru && p['nip'] != null && p['nip']!.toString().isNotEmpty)
              Text('NIP: ${p['nip']}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Reset password (79xxxx)',
                onPressed: () => _resetPw(p)),
            IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                tooltip: 'Hapus',
                onPressed: () => _delete(p)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: DashboardHeader(
        title: 'MANAJEMEN AKUN',
        subtitle: 'Kelola akun guru & panitia',
        actions: const [LogoutButton()],
      ),
      body: ContentMaxWidth(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Buat Akun Baru',
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(
                                    'Password otomatis format 79xxxx, dicatat setelah berhasil.',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600)),
                                const SizedBox(height: 12),
                                RadioListTile(
                                  title: const Text('Akun Guru',
                                      style: TextStyle(fontSize: 13)),
                                  value: 'guru',
                                  groupValue: _rolePilih,
                                  onChanged: (v) =>
                                      setState(() => _rolePilih = v as String),
                                  dense: true,
                                ),
                                RadioListTile(
                                  title: const Text('Akun Panitia',
                                      style: TextStyle(fontSize: 13)),
                                  value: 'panitia',
                                  groupValue: _rolePilih,
                                  onChanged: (v) =>
                                      setState(() => _rolePilih = v as String),
                                  dense: true,
                                ),
                                const SizedBox(height: 4),
                                TextField(
                                    controller: _namaCtrl,
                                    decoration: const InputDecoration(
                                        labelText: 'Nama lengkap *')),
                                const SizedBox(height: 8),
                                if (_rolePilih == 'guru') ...[
                                  TextField(
                                      controller: _nipCtrl,
                                      decoration: const InputDecoration(
                                          labelText: 'NIP (opsional)')),
                                  const SizedBox(height: 8),
                                  TextField(
                                      controller: _jabatanCtrl,
                                      decoration: const InputDecoration(
                                          labelText: 'Jabatan (opsional)')),
                                  const SizedBox(height: 8),
                                ],
                                TextField(
                                    controller: _emailCtrl,
                                    decoration: InputDecoration(
                                        labelText:
                                            'Email login (wajib valid, contoh: guru@smkyp79.my.id)')),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                            backgroundColor: AppTheme.primary),
                                        onPressed: _creating ? null : _create,
                                        icon: _creating
                                            ? const SizedBox(
                                                height: 16,
                                                width: 16,
                                                child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white))
                                            : const Icon(Icons.person_add, size: 18),
                                        label: const Text('Buat Akun'),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                        onPressed: _resetForm,
                                        child: const Text('Bersihkan')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Akun Guru (${_guruList.length})',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (_guruList.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('Belum ada akun guru.',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          )
                        else
                          ..._guruList.map((p) => _akunRow(p, isGuru: true)),
                        const SizedBox(height: 12),
                        Text('Akun Panitia (${_panitiaList.length})',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        if (_panitiaList.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text('Belum ada akun panitia.',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          )
                        else
                          ..._panitiaList
                              .map((p) => _akunRow(p, isGuru: false)),
                      ],
                    ),
                  ),
      ),
    );
  }
}
