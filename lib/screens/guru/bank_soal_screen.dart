import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../shared/soal_form_screen.dart';

class BankSoalScreen extends StatefulWidget {
  const BankSoalScreen({super.key});

  @override
  State<BankSoalScreen> createState() => _BankSoalScreenState();
}

class _BankSoalScreenState extends State<BankSoalScreen> {
  List<Map<String, dynamic>> _soal = [];
  List<Map<String, dynamic>> _mapelList = [];
  String? _filterMapel;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _loadMapel();
  }

  Future<void> _loadMapel() async {
    try {
      final rows = await Api.client
          .from('mata_pelajaran')
          .select('id,nama')
          .order('nama');
      if (!mounted) return;
      setState(() => _mapelList = List<Map<String, dynamic>>.from(rows));
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var q = Api.client
          .from('bank_soal')
          .select('*,mata_pelajaran(nama)');
      if (_filterMapel != null) q = q.eq('mapel_id', _filterMapel!);
      final rows = await q.order('created_at', ascending: false);
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

  Future<void> _add() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SoalFormScreen()),
    );
    _load();
  }

  Future<void> _edit(Map<String, dynamic> soal) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => SoalFormScreen(initial: soal, soalId: soal['id'])),
    );
    _load();
  }

  Future<void> _delete(Map<String, dynamic> soal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus Soal'),
        content: Text(
            'Yakin hapus soal: ${(soal['soal'] ?? '').toString().length > 60 ? '${(soal['soal'] ?? '')}'.substring(0, 60) + '...' : soal['soal']}'),
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
      await Api.client.from('bank_soal').delete().eq('id', soal['id']);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal hapus: $e'),
              backgroundColor: AppTheme.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Bank Soal'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            color: Colors.white,
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Semua', style: TextStyle(fontSize: 12)),
                    selected: _filterMapel == null,
                    onSelected: (_) { setState(() => _filterMapel = null); _load(); },
                  ),
                  const SizedBox(width: 6),
                  for (final m in _mapelList)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text('${m['nama']}',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                        selected: _filterMapel == m['id'],
                        onSelected: (on) { setState(() => _filterMapel = on ? m['id'].toString() : null); _load(); },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
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
    if (_error != null) return Center(child: Text(_error!));
    if (_soal.isEmpty) {
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
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _soal.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, i) {
          final s = _soal[i];
          final mapel = (s['mata_pelajaran'] is Map)
              ? (s['mata_pelajaran'] as Map)['nama']?.toString() ?? ''
              : '';
          final jenis = s['jenis']?.toString() ?? 'pg';
          final text = s['soal']?.toString() ?? '';
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: jenis == 'pg'
                    ? AppTheme.primary.withOpacity(0.1)
                    : AppTheme.accent.withOpacity(0.1),
                foregroundColor:
                    jenis == 'pg' ? AppTheme.primary : AppTheme.accent,
                child: Text(jenis == 'pg' ? 'PG' : 'ES',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              title: Text(
                text.length > 60 ? '${text.substring(0, 60)}...' : text,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text([
                if (mapel.isNotEmpty) mapel,
                'Bobot: ${s['bobot'] ?? 1}',
              ].join(' • ')),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _edit(s)),
                  IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppTheme.danger),
                      onPressed: () => _delete(s)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}