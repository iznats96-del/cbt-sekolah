import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/app_theme.dart';
import '../../core/config.dart';
import '../../services/api.dart';
import '../auth/login_screen.dart';
import 'pelaksanaan_screen.dart';

class UjianBerandaList extends StatefulWidget {
  const UjianBerandaList({super.key});

  @override
  State<UjianBerandaList> createState() => _UjianBerandaListState();
}

class _UjianBerandaListState extends State<UjianBerandaList> {
  List<dynamic> _ujian = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // kalau sesi sudah kedaluwarsa → paksakan refresh dulu (diem-diem)
    final s = Api.client.auth.currentSession;
    if (s != null &&
        DateTime.fromMillisecondsSinceEpoch((s.expiresAt ?? 0) * 1000)
            .isBefore(DateTime.now().subtract(const Duration(minutes: 1)))) {
      try {
        await Api.client.auth.refreshSession();
      } catch (_) {
        if (mounted) {
          await Api.client.auth.signOut();
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (r) => false);
          }
        }
        return;
      }
    }
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        // RPC AMAN: tanpa token & tanpa kunci
        final rows = await Api.client.rpc('my_ujian_aktif');
        if (!mounted) return;
        dynamic data = rows;
        if (data is String) data = jsonDecode(data);
        debugPrint('CBT-DIAG list=${data.length} user=${Api.user?.email}');
        setState(() {
          _ujian = List<dynamic>.from(data as List);
          _loading = false;
        });
        return;
      } catch (e) {
        if (attempt == 0) {
          // satu retry setelah coba refresh (rate-limit & network flake)
          await Future.delayed(const Duration(milliseconds: 1200));
          continue;
        }
        if (!mounted) return;
        debugPrint('CBT-DIAG ERROR $e');
          setState(() {
          _error = 'Gagal memuat: $e';
          _loading = false;
        });
      }
    }
  }

  /// Probe mentah REST (jalur sama dgn supabase lib) utk diagnosa layar kosong.
  Future<String> _diag() async {
    final s = Api.client.auth.currentSession;
    if (s == null) return 'NO SESSION (login ulang)';
    try {
      final r = await http
          .post(
            Uri.parse('${AppConfig.supabaseUrl}/rest/v1/rpc/my_ujian_aktif'),
            headers: {
              'apikey': AppConfig.supabaseAnonKey,
              'Authorization': 'Bearer ${s.accessToken}',
              'Content-Type': 'application/json',
            },
            body: '{}',
          )
          .timeout(const Duration(seconds: 10));
      final body = r.body.trim();
      return 'HTTP ${r.statusCode} → ${body.length > 170 ? '${body.substring(0, 170)}…' : body}';
    } catch (e) {
      return 'NET ERROR: $e';
    }
  }

  Future<void> _start(Map<String, dynamic> u) async {
    // ===== TANPA TOKEN: cukup konfirmasi, langsung mengerjakan =====
    final lanjut = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Mulai Ujian?'),
        content: Text(
            '${u['nama']}\n\n'
            '• ${u['mapel'] ?? ''}\n'
            '• ${u['alokasi_menit'] ?? '?'} menit • ${u['jumlah_soal'] ?? '?'} soal\n\n'
            'Waktu mulai berjalan begitu kamu masuk. Pastikan siap.',
            style: const TextStyle(fontSize: 13, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Kerjakan')),
        ],
      ),
    );
    if (lanjut != true) return;

    // registrasi peserta di SERVER (token kosong -> sistem tanpa token)
    try {
      final pesertaId =
          await Api.client.rpc('cek_token_ujian', params: {
        'p_ujian': u['id'],
        'p_token': '',
      });
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PelaksanaanScreen(
          ujian: u,
          pesertaId: pesertaId.toString(),
        ),
      ));
    } catch (e) {
      final msg = e.toString();
      _snack(msg.contains('Sudah mengerjakan')
          ? 'Kamu sudah mengerjakan ujian ini.'
          : msg.contains('luar jadwal') || msg.contains('tidak tersedia')
              ? 'Ujian belum dibuka sesuai jadwal.'
              : msg.contains('Bukan kelas')
                  ? 'Ujian ini untuk kelas lain.'
                  : 'Gagal: ${_clean(msg)}', error: true);
    }
  }

  String _clean(String s) {
    final m = RegExp(r'"message":"([^"]+)"').firstMatch(s) ??
        RegExp(r': (.+)$').firstMatch(s);
    return m?.group(1) ?? s;
  }

  void _snack(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m),
        backgroundColor: error ? AppTheme.danger : null));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.danger, size: 40),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Muat Ulang')),
            ],
          ),
        ),
      );
    }
    if (_ujian.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.rule_folder_outlined,
                  size: 40, color: AppTheme.accent),
              const SizedBox(height: 10),
              const Text('Belum ada ujian aktif untukmu.\nTarik ke bawah utk muat ulang.',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.4)),
              const SizedBox(height: 14),
              if (kDebugMode)
                FutureBuilder<String>(
                  future: _diag(),
                  builder: (c, snap) => Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        'DIAGNOSTIK\nlogin : ${Api.user?.email ?? '(belum login)'}\nrole  : ${Api.role ?? '-'}\ncepat : ${snap.data ?? '(cek)'}',
                        style: const TextStyle(fontSize: 10.5, height: 1.5),
                      ),
                    ),
                  ),
                ),
              if (kDebugMode) const SizedBox(height: 10),
              FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Cek Ulang')),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        for (int i = 0; i < _ujian.length; i++) ...[
          Builder(builder: (context) {
            final u = Map<String, dynamic>.from(_ujian[i] as Map);
            return Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${u['nama'] ?? 'Ujian'}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if ((u['mapel'] ?? '').toString().isNotEmpty)
                      _row(Icons.menu_book_outlined, '${u['mapel']}'),
                    if ((u['kelas'] ?? '').toString().isNotEmpty)
                      _row(Icons.groups_outlined, '${u['kelas']}'),
                    if ((u['tanggal'] ?? '').toString().isNotEmpty)
                      _row(Icons.event_outlined, 'Tanggal: ${u['tanggal']}'),
                    if ((u['jam'] ?? '').toString().isNotEmpty)
                      _row(Icons.schedule_outlined, 'Jam ujian: ${u['jam']}'),
                    _row(Icons.timer_outlined,
                        '${u['alokasi_menit'] ?? '?'} menit • ${u['jumlah_soal'] ?? '?'} soal'),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _start(u),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Kerjakan Ujian'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          if (i != _ujian.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _row(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey[800])),
          ),
        ],
      ),
    );
  }
}