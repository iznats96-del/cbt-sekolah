import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../shared/soal_form_screen.dart';
import '../admin/import_ujian_screen.dart';

/// Bank Soal GURU — tampil PER MAPEL (tap mapel -> lihat soal-soalnya).
class BankSoalScreen extends StatefulWidget {
  const BankSoalScreen({super.key});

  @override
  State<BankSoalScreen> createState() => _BankSoalScreenState();
}

class _BankSoalScreenState extends State<BankSoalScreen> {
  List<Map<String, dynamic>> _soal = [];
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
      final rows = await Api.client
          .from('bank_soal')
          .select('*,mata_pelajaran(nama)')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _soal = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat soal: $e';
        _loading = false;
      });
    }
  }

  /// Kelompokkan soal per mapel.
  Map<String, List<Map<String, dynamic>>> get _byMapel {
    final out = <String, List<Map<String, dynamic>>>{};
    for (final s in _soal) {
      final mp = s['mata_pelajaran'];
      final nama = (mp is Map ? '${mp['nama']}' : '') .trim();
      final key = nama.isEmpty ? '(tanpa mapel)' : nama;
      (out[key] ??= []).add(s);
    }
    return out;
  }

  Future<void> _add() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SoalFormScreen()),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Bank Soal'),
        actions: [
          IconButton(
            tooltip: 'Import soal dari naskah .docx',
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: () async {
              final ok = await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ImportUjianScreen()),
              );
              if (ok == true) _load();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: AppTheme.danger, size: 40),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Muat Ulang')),
          ]),
        ),
      );
    }
    final groups = _byMapel;
    if (groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.quiz_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Belum ada soal', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            FilledButton(onPressed: _add, child: const Text('+ Buat Soal')),
          ],
        ),
      );
    }
    final keys = groups.keys.toList()..sort();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: keys.length,
        itemBuilder: (context, i) {
          final nama = keys[i];
          final list = groups[nama]!;
          // ringkas jenis: berapa PG / jodoh / esai
          int pg = 0, jd = 0, es = 0;
          for (final s in list) {
            final j = s['jenis']?.toString() ?? 'pg';
            if (j == 'pg') pg++; else if (j == 'jodoh') jd++; else es++;
          }
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.primary.withOpacity(0.12),
                child: const Icon(Icons.menu_book_outlined, color: AppTheme.primary, size: 22),
              ),
              title: Text(nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
              subtitle: Text('${list.length} soal  •  PG $pg · Jodoh $jd · Esai $es',
                  style: const TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SoalPerMapelScreen(namaMapel: nama, soal: list),
                ));
                _load();
              },
            ),
          );
        },
      ),
    );
  }
}

/// Daftar soal milik SATU mapel — bisa edit/hapus.
class SoalPerMapelScreen extends StatefulWidget {
  final String namaMapel;
  final List<Map<String, dynamic>> soal;
  const SoalPerMapelScreen({super.key, required this.namaMapel, required this.soal});

  @override
  State<SoalPerMapelScreen> createState() => _SoalPerMapelScreenState();
}

class _SoalPerMapelScreenState extends State<SoalPerMapelScreen> {
  late List<Map<String, dynamic>> _soal = List.of(widget.soal);

  Future<void> _edit(Map<String, dynamic> soal) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SoalFormScreen(initial: soal, soalId: soal['id'])));
    _refresh();
  }

  Future<void> _refresh() async {
    final rows = await Api.client
        .from('bank_soal')
        .select('*,mata_pelajaran(nama)')
        .order('created_at', ascending: false);
    final filtered = List<Map<String, dynamic>>.from(rows).where((s) {
      final mp = s['mata_pelajaran'];
      final nama = (mp is Map ? '${mp['nama']}' : '').trim();
      return (nama.isEmpty ? '(tanpa mapel)' : nama) == widget.namaMapel;
    }).toList();
    if (mounted) setState(() => _soal = filtered);
  }

  Future<void> _delete(Map<String, dynamic> soal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus Soal'),
        content: Text('Yakin hapus soal ini?\n\n${soal['soal']}',
            style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.client.from('bank_soal').delete().eq('id', soal['id']);
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal hapus: $e'), backgroundColor: AppTheme.danger));
    }
  }

  String _jenisLabel(String j) => j == 'pg' ? 'PG' : j == 'jodoh' ? 'JODOH' : 'ESAI';
  Color _jenisColor(String j) =>
      j == 'pg' ? AppTheme.primary : j == 'jodoh' ? AppTheme.accent : const Color(0xFFF4A940);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: Text(widget.namaMapel)),
      body: _soal.isEmpty
          ? const Center(child: Text('Tidak ada soal', style: TextStyle(color: Colors.grey)))
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _soal.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final s = _soal[i];
                  final jenis = s['jenis']?.toString() ?? 'pg';
                  final text = s['soal']?.toString() ?? '';
                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 20,
                        backgroundColor: _jenisColor(jenis).withOpacity(0.12),
                        child: Text(_jenisLabel(jenis),
                            style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: _jenisColor(jenis))),
                      ),
                      title: Text(
                        text.length > 70 ? '${text.substring(0, 70)}...' : text,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                      subtitle: Text('Bobot: ${s['bobot'] ?? 1}',
                          style: const TextStyle(fontSize: 11.5)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(s)),
                          IconButton(
                              icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                              onPressed: () => _delete(s)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
