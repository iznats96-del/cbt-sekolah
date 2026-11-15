import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../../widgets/state_views.dart';
import '../home.dart' show LogoutButton;
import '../shared/soal_detail_screen.dart';
import '../shared/soal_form_screen.dart';
import '../admin/import_ujian_screen.dart';

/// Bank Soal — REWRITE v3: MASTER-DETAIL per MAPEL.
///
/// Halaman root = LIST MAPEL (kartu, ada jumlah soal). Tap mapel → buka halaman
/// [MapelSoalPage] berisi list soal mapel itu (search + filter jenis PG/Essay).
/// Tap soal → detail.
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
          .select('id,mapel_id,jenis,mata_pelajaran(nama),kelas(nama)')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _soal = List<Map<String, dynamic>>.from(rows);
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

  /// {mapel_id: (nama, total, pg, essay)}
  Map<String, ({String nama, int total, int pg, int essay})> get _byMapel {
    final out = <String, ({String nama, int total, int pg, int essay})>{};
    for (final s in _soal) {
      final mp = s['mata_pelajaran'];
      final id = '${s['mapel_id'] ?? ''}';
      if (id.isEmpty) continue;
      final nama = mp is Map ? '${mp['nama']}' : '(tanpa nama)';
      final cur = out[id] ?? (nama: nama, total: 0, pg: 0, essay: 0);
      final isEssay = (s['jenis'] ?? 'pg').toString() == 'essay';
      out[id] = (
        nama: cur.nama,
        total: cur.total + 1,
        pg: cur.pg + (isEssay ? 0 : 1),
        essay: cur.essay + (isEssay ? 1 : 0),
      );
    }
    return out;
  }

  Future<void> _addSoal() async {
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
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        onPressed: _addSoal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Soal', style: TextStyle(color: Colors.white)),
      ),
      body: ContentMaxWidth(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    final mapels = _byMapel;
    if (mapels.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: const [
          SizedBox(height: 100),
          Center(
            child: Text('Belum ada soal.\nBuat soal pertama dengan tombol + di bawah.',
                textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ),
        ]),
      );
    }

    final entries = mapels.entries.toList()
      ..sort((a, b) => a.value.nama.compareTo(b.value.nama));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final e = entries[i];
          return _mapelCard(e.key, e.value);
        },
      ),
    );
  }

  Widget _mapelCard(String mapelId, ({String nama, int total, int pg, int essay}) info) {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MapelSoalPage(mapelId: mapelId, mapelNama: info.nama),
          ),
        );
        _load();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.menu_book_outlined, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info.nama,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 3),
                  Text('${info.total} soal · PG ${info.pg} · Essay ${info.essay}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

/// ============ HALAMAN 2: LIST SOAL DALAM 1 MAPEL ============
class MapelSoalPage extends StatefulWidget {
  final String mapelId;
  final String mapelNama;
  const MapelSoalPage({super.key, required this.mapelId, required this.mapelNama});

  @override
  State<MapelSoalPage> createState() => _MapelSoalPageState();
}

class _MapelSoalPageState extends State<MapelSoalPage> {
  List<Map<String, dynamic>> _soal = [];
  bool _loading = true;
  String? _error;
  String _filterJenis = 'semua'; // semua|pg|essay
  String _search = '';
  final _searchCtrl = TextEditingController();

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
          .select('*,mata_pelajaran(nama),kelas(nama)')
          .eq('mapel_id', widget.mapelId)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _soal = List<Map<String, dynamic>>.from(rows);
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

  List<Map<String, dynamic>> get _filtered {
    Iterable<Map<String, dynamic>> out = _soal;
    if (_filterJenis != 'semua') {
      out = out.where((s) => (s['jenis'] ?? 'pg').toString() == _filterJenis);
    }
    if (_search.trim().isNotEmpty) {
      final q = _search.toLowerCase();
      out = out.where((s) =>
          (s['soal']?.toString().toLowerCase().contains(q) ?? false) ||
          (s['pembahasan']?.toString().toLowerCase().contains(q) ?? false));
    }
    return out.toList();
  }

  Future<void> _add() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SoalFormScreen(initial: {'mapel_id': widget.mapelId})),
    );
    _load();
  }

  Future<void> _edit(Map<String, dynamic> soal) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SoalFormScreen(initial: soal, soalId: soal['id']),
      ),
    );
    _load();
  }

  Future<void> _delete(Map<String, dynamic> soal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus soal?'),
        content: Text((soal['soal'] ?? '').toString(),
            maxLines: 3, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.client.from('bank_soal').delete().eq('id', soal['id']);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Soal dihapus'), backgroundColor: AppTheme.danger),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal hapus: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pgCount = _soal.where((s) => (s['jenis'] ?? 'pg').toString() != 'essay').length;
    final essayCount = _soal.length - pgCount;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: Text(widget.mapelNama)),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        onPressed: _add,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Soal', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
              decoration: InputDecoration(
                hintText: 'Cari soal di ${widget.mapelNama}…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
          ),
          // Filter jenis
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _chip('Semua', _filterJenis == 'semua',
                    () => setState(() => _filterJenis = 'semua')),
                _chip('PG ($pgCount)', _filterJenis == 'pg',
                    () => setState(() => _filterJenis = 'pg')),
                _chip('Essay ($essayCount)', _filterJenis == 'essay',
                    () => setState(() => _filterJenis = 'essay')),
              ],
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildList() {
    final list = _filtered;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (list.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 80),
        Center(child: Text('Belum ada soal di mapel ini', style: TextStyle(color: Colors.grey))),
      ]);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _soalRow(list[i]),
      ),
    );
  }

  Widget _soalRow(Map<String, dynamic> s) {
    final jenis = (s['jenis'] ?? 'pg').toString();
    final isEssay = jenis == 'essay';
    final kelasNama = s['kelas'] is Map ? '${(s['kelas'] as Map)['nama'] ?? ''}' : '';
    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(
              builder: (_) => SoalDetailScreen(soalId: s['id'].toString())))
          .then((_) => _load()),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: (isEssay ? const Color(0xFFF4A940) : AppTheme.primary)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                isEssay ? 'ESSAY' : 'PG',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isEssay ? const Color(0xFFF4A940) : AppTheme.primary),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (s['soal'] ?? '').toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (kelasNama.isNotEmpty) _miniTag(Icons.school_outlined, kelasNama, const Color(0xFF1D4ED8)),
                      _miniTag(Icons.star_outline, 'bobot ${s['bobot'] ?? 1}', Colors.grey),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
              tooltip: 'Edit',
              onPressed: () => _edit(s),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniTag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
