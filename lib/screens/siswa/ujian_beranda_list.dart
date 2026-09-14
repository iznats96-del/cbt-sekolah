import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
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
    try {
      // RPC AMAN: tanpa token & tanpa kunci
      final rows = await Api.client.rpc('my_ujian_aktif');
      if (!mounted) return;
      setState(() {
        _ujian = List<dynamic>.from(rows as List);
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

  Future<void> _start(Map<String, dynamic> u) async {
    final tokenCtrl = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Masukkan Token'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Token diberikan pengawas ujian untuk: ${u['nama']}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: tokenCtrl,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, letterSpacing: 6),
              decoration: const InputDecoration(hintText: '••••••'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(c, tokenCtrl.text.trim().toUpperCase()),
              child: const Text('Masuk')),
        ],
      ),
    );
    if (token == null || token.isEmpty) return;

    // verifikasi TOKEN di SERVER + registrasi peserta otomatis
    try {
      final pesertaId =
          await Api.client.rpc('cek_token_ujian', params: {
        'p_ujian': u['id'],
        'p_token': token,
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
      _snack(msg.contains('Salah token')
          ? 'Token salah! Minta token ke pengawas.'
          : msg.contains('Sudah mengerjakan')
              ? 'Kamu sudah mengerjakan ujian ini.'
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
      return const Center(
        child: Text('Belum ada ujian aktif.\nSabar ya.', textAlign: TextAlign.center),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _ujian.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
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
        },
      ),
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