import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../../widgets/state_views.dart';
import '../home.dart';
import '../shared/soal_form_screen.dart';
import '../admin/import_ujian_screen.dart';

/// Bank Soal ADMIN - layout per mapel, grup PG / Menjodohkan / Essay di dalam tiap mapel.
class BankSoalScreen extends StatefulWidget {
  const BankSoalScreen({super.key});

  @override
  State<BankSoalScreen> createState() => _BankSoalScreenState();
}

class _BankSoalScreenState extends State<BankSoalScreen> {
  List<Map<String, dynamic>> _soal = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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

  Map<String, List<Map<String, dynamic>>> get _byMapel {
    final out = <String, List<Map<String, dynamic>>>{};
    for (final s in _soal) {
      final mp = s['mata_pelajaran'];
      final nama = (mp is Map ? '${mp['nama']}' : '').trim();
      final key = nama.isEmpty ? '(tanpa mapel)' : nama;
      (out[key] ??= []).add(s);
    }
    return out;
  }

  List<Map<String, dynamic>> _filterSoal(List<Map<String, dynamic>> list) {
    if (_search.isEmpty) return list;
    final q = _search.toLowerCase();
    return list
        .where((s) =>
            (s['soal']?.toString().toLowerCase().contains(q) ?? false) ||
            (s['pembahasan']?.toString().toLowerCase().contains(q) ?? false))
        .toList();
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
          const LogoutButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: ContentMaxWidth(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }

    final searchBar = Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v.trim()),
        decoration: InputDecoration(
          hintText: 'Cari soal...',
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      ),
    );

    if (_soal.isEmpty) {
      return Column(
        children: [
          searchBar,
          const EmptyState(
            icon: Icons.quiz_outlined,
            title: 'Belum ada soal',
            subtitle:
                'Buat soal dengan tombol + atau import naskah DOCX dari ikon upload.',
          ),
        ],
      );
    }

    final groups = _byMapel;
    final keys = groups.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          searchBar,
          for (final nama in keys)
            MapelCard(
              nama: nama,
              soal: _filterSoal(groups[nama]!),
              onChanged: _load,
              onAdd: _add,
            ),
        ],
      ),
    );
  }
}

/// Kartu mapel berisi grup PG / Menjodohkan / Essay (yang kosong di-skip).
class MapelCard extends StatefulWidget {
  final String nama;
  final List<Map<String, dynamic>> soal;
  final VoidCallback onChanged;
  final VoidCallback onAdd;

  const MapelCard({
    super.key,
    required this.nama,
    required this.soal,
    required this.onChanged,
    required this.onAdd,
  });

  @override
  State<MapelCard> createState() => _MapelCardState();
}

class _MapelCardState extends State<MapelCard> {
  Set<String> _openGrupos = {'pg', 'essay'};

  List<Map<String, dynamic>> _byJenis(String jenis) =>
      widget.soal.where((s) => (s['jenis'] ?? 'pg').toString() == jenis).toList();

  void _toggleGrupos(String g) {
    setState(() {
      if (!_openGrupos.contains(g)) {
        _openGrupos.add(g);
      } else {
        _openGrupos.remove(g);
      }
    });
  }

  Future<void> _edit(Map<String, dynamic> soal) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SoalFormScreen(initial: soal, soalId: soal['id'])));
    widget.onChanged();
  }

  Future<void> _delete(Map<String, dynamic> soal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus Soal'),
        content: Text('Yakin hapus soal ini?\n\n${soal['soal']}',
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
      await Api.client.from('bank_soal').delete().eq('id', soal['id']);
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal hapus: $e'),
          backgroundColor: AppTheme.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pgList = _byJenis('pg');
    final jodohList = _byJenis('jodoh');
    final essayList = _byJenis('essay');

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                  child: Icon(Icons.menu_book_outlined,
                      color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.nama,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(
                          '${pgList.length + jodohList.length + essayList.length} soal',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 22),
                  tooltip: 'Buat soal di mapel ini',
                  onPressed: widget.onAdd,
                ),
              ],
            ),
            Divider(height: 1, color: Colors.grey.shade200),

            if (pgList.isNotEmpty)
              _groupWidget(
                  'pg',
                  'Pilihan Ganda',
                  pgList.length,
                  AppTheme.primary,
                  pgList),

            if (jodohList.isNotEmpty)
              _groupWidget(
                  'jodoh',
                  'Menjodohkan',
                  jodohList.length,
                  AppTheme.accent,
                  jodohList),

            if (essayList.isNotEmpty)
              _groupWidget(
                  'essay',
                  'Essay',
                  essayList.length,
                  const Color(0xFFF4A940),
                  essayList),
          ],
        ),
      ),
    );
  }

  Widget _groupWidget(String id, String label, int count, Color color,
      List<Map<String, dynamic>> items) {
    final open = _openGrupos.contains(id);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: color)),
              ),
              const SizedBox(width: 6),
              Text('$count soal',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              const Spacer(),
              IconButton(
                icon:
                    Icon(open ? Icons.expand_less : Icons.expand_more, size: 18),
                onPressed: () => _toggleGrupos(id),
              ),
            ],
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                children: [
                  for (final s in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _soalRow(s),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _soalRow(Map<String, dynamic> s) {
    final text = s['soal']?.toString() ?? '';
    final jenis = (s['jenis'] ?? 'pg').toString();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (jenis == 'pg'
                            ? AppTheme.primary
                            : jenis == 'jodoh'
                                ? AppTheme.accent
                                : const Color(0xFFF4A940))
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(jenis.toUpperCase(),
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: jenis == 'pg'
                                  ? AppTheme.primary
                                  : jenis == 'jodoh'
                                      ? AppTheme.accent
                                      : const Color(0xFFF4A940))),
                    ),
                    const SizedBox(width: 8),
                    Text('Bobot: ${s['bobot'] ?? 1}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  text.length > 70 ? '${text.substring(0, 70)}...' : text,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: 'Edit',
            onPressed: () => _edit(s),
          ),
          IconButton(
            icon:
                const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
            tooltip: 'Hapus',
            onPressed: () => _delete(s),
          ),
        ],
      ),
    );
  }
}
