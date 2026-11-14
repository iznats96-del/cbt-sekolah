import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../../widgets/state_views.dart';
import '../shared/soal_detail_screen.dart';
import '../shared/soal_form_screen.dart';
import '../admin/import_ujian_screen.dart';
import '../home.dart' show LogoutButton;
import '../../widgets/state_views.dart' show ContentMaxWidth;

/// Bank Soal — REWRITE TOTAL (v2).
///
/// Konsep:
///   Filter bar (chips: Kelas | Mapel | Jenis) → hasil FLAT LIST.
///   Gak ada nesting mapel-dalam-kelas; semua difilter via chip, list tetap satu.
///   Chip kelas = "Semua" + daftar kelas; chip mapel = "Semua" + daftar mapel;
///   chip jenis = Semua / PG / Essay.
///
/// Fitur tetap: search, badge kelas+jenis, edit/hapus, import DOCX, detail soal.
class BankSoalScreen extends StatefulWidget {
  const BankSoalScreen({super.key});

  @override
  State<BankSoalScreen> createState() => _BankSoalScreenState();
}

class _BankSoalScreenState extends State<BankSoalScreen> {
  List<Map<String, dynamic>> _soal = [];
  List<({String id, String nama})> _kelasList = [];
  List<({String id, String nama})> _mapelList = [];

  String? _filterKelas; // null = semua
  String? _filterMapel;
  String _filterJenis = 'semua'; // semua|pg|essay
  String _search = '';
  final _searchCtrl = TextEditingController();

  bool _loading = true;
  String? _error;

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
          .order('created_at', ascending: false);
      final kelasRows = await Api.client.from('kelas').select('id,nama').order('nama');
      final mapelRows = await Api.client.from('mata_pelajaran').select('id,nama').order('nama');
      if (!mounted) return;
      setState(() {
        _soal = List<Map<String, dynamic>>.from(rows);
        _kelasList = [
          for (final k in (kelasRows as List))
            (id: '${k['id']}', nama: '${k['nama']}'),
        ];
        _mapelList = [
          for (final m in (mapelRows as List))
            (id: '${m['id']}', nama: '${m['nama']}'),
        ];
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
    if (_filterKelas != null) {
      out = out.where((s) => '${s['kelas_id'] ?? ''}' == _filterKelas);
    }
    if (_filterMapel != null) {
      out = out.where((s) => '${s['mapel_id'] ?? ''}' == _filterMapel);
    }
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

  Map<int, int> get _countByJenis {
    final out = <int, int>{};
    for (final s in _filtered) {
      final j = (s['jenis'] ?? 'pg').toString() == 'essay' ? 1 : 0;
      out[j] = (out[j] ?? 0) + 1;
    }
    return out;
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
        onPressed: _add,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Soal', style: TextStyle(color: Colors.white)),
      ),
      body: ContentMaxWidth(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    return Column(
      children: [
        // ===== SEARCH =====
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Cari soal…',
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
        // ===== FILTER CHIPS =====
        _filterBar(),
        // ===== SUMMARY =====
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text('${_filtered.length} soal',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 12),
              Text('PG ${_countByJenis[0] ?? 0} · Essay ${_countByJenis[1] ?? 0}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
        // ===== LIST =====
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _filterBar() {
    return SizedBox(
      height: 100,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _chipRow(
            label: 'Kelas',
            items: [
              (id: null as String?, nama: 'Semua'),
              for (final k in _kelasList) (id: k.id as String?, nama: k.nama),
            ],
            selected: _filterKelas,
            onSelect: (v) => setState(() => _filterKelas = v),
          ),
          const SizedBox(height: 6),
          _chipRow(
            label: 'Mapel',
            items: [
              (id: null as String?, nama: 'Semua'),
              for (final m in _mapelList) (id: m.id as String?, nama: m.nama),
            ],
            selected: _filterMapel,
            onSelect: (v) => setState(() => _filterMapel = v),
          ),
          const SizedBox(height: 6),
          _chipRow(
            label: 'Jenis',
            items: const [
              (id: 'semua' as String?, nama: 'Semua'),
              (id: 'pg', nama: 'PG'),
              (id: 'essay', nama: 'Essay'),
            ],
            selected: _filterJenis,
            onSelect: (v) => setState(() => _filterJenis = v ?? 'semua'),
          ),
        ],
      ),
    );
  }

  Widget _chipRow({
    required String label,
    required List<({String? id, String nama})> items,
    required String? selected,
    required void Function(String?) onSelect,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 42,
          child: Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final it in items)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(it.nama, style: const TextStyle(fontSize: 12)),
                      selected: selected == it.id,
                      onSelected: (_) => onSelect(it.id),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList() {
    final list = _filtered;
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            Center(child: Text('Tidak ada soal yang cocok', style: TextStyle(color: Colors.grey))),
          ],
        ),
      );
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
    final mapelNama = s['mata_pelajaran'] is Map ? '${(s['mata_pelajaran'] as Map)['nama'] ?? ''}' : '';
    return Dismissible(
      key: ValueKey(s['id'].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        color: AppTheme.danger,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await _delete(s);
        return false; // hapus via dialog; jangan dismiss row biar list reload rapi
      },
      child: GestureDetector(
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
              // badge jenis
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
                        if (mapelNama.isNotEmpty)
                          _miniTag(Icons.menu_book_outlined, mapelNama, Colors.grey),
                        if (kelasNama.isNotEmpty)
                          _miniTag(Icons.school_outlined, kelasNama, const Color(0xFF1D4ED8)),
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
