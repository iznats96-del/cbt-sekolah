import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import 'crud_kelas_screen.dart';

/// Komponen Kelas/Rombel modern: kelompok tingkat X / XI / XII,
/// tap sebuah rombel => accordion daftar anggotanya (murid).
class KelasRombelScreen extends StatefulWidget {
  const KelasRombelScreen({super.key});

  @override
  State<KelasRombelScreen> createState() => _KelasRombelScreenState();
}

class _KelasRombelScreenState extends State<KelasRombelScreen> {
  List<Map<String, dynamic>> _kelas = [];
  List<Map<String, dynamic>> _jurusan = [];
  List<Map<String, dynamic>> _siswa = [];
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
      final res = await Future.wait([
        Api.client.from('kelas').select('*,jurusan(singkatan,nama)').order('nama'),
        Api.client.from('jurusan').select('id,nama,singkatan').order('singkatan'),
        Api.client.from('siswa').select('id,nis,nama,jenis_kelamin,aktive_ok,kelas_id').order('nama').limit(2000),
      ]);
      if (!mounted) return;
      setState(() {
        _kelas = List<Map<String, dynamic>>.from(res[0]);
        _jurusan = List<Map<String, dynamic>>.from(res[1]);
        _siswa = List<Map<String, dynamic>>.from(res[2]);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  List<String> get _tingkats {
    final t = <String>{};
    for (final k in _kelas) {
      t.add(kelasTingkat('${k['nama']}'));
    }
    final ordered = ['X', 'XI', 'XII'].where(t.contains).toList();
    return [...ordered, ...t.where((x) => !ordered.contains(x))];
  }

  List<Map<String, dynamic>> _rombelOf(String tingkat) =>
      _kelas.where((k) => kelasTingkat('${k['nama']}') == tingkat).toList()
        ..sort((a, b) => '${a['nama']}'.compareTo('${b['nama']}'));

  List<Map<String, dynamic>> _anggota(String kelasId) =>
      _siswa.where((s) => s['kelas_id']?.toString() == kelasId).toList();

  String _singkatan(Map<String, dynamic> k) {
    final j = k['jurusan'];
    if (j is Map && j['singkatan'] != null) return '${j['singkatan']}';
    return '';
  }

  Future<void> _form({Map<String, dynamic>? row}) async {
    final namaCtrl = TextEditingController(text: row?['nama']?.toString() ?? '');
    String? tingkat = row?['tingkat']?.toString();
    String? jurusanId = row?['jurusan_id']?.toString();
    if (tingkat == null && namaCtrl.text.isNotEmpty) {
      tingkat = namaTingkatFromStr(namaCtrl.text);
    }
    tingkat ??= 'X';

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(row == null ? 'Tambah Rombel' : 'Edit Rombel'),
        content: StatefulBuilder(
          builder: (c, setSt) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: namaCtrl,
                autofocus: row == null,
                decoration: const InputDecoration(
                    labelText: 'Nama rombel *', hintText: 'cth: XII TKJ 2'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: tingkat,
                borderRadius: BorderRadius.circular(12),
                decoration: const InputDecoration(labelText: 'Tingkat'),
                items: const ['X', 'XI', 'XII']
                    .map((t) => DropdownMenuItem(value: t, child: Text('Kelas $t')))
                    .toList(),
                onChanged: (v) => setSt(() => tingkat = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String?>(
                value: jurusanId,
                borderRadius: BorderRadius.circular(12),
                decoration: const InputDecoration(labelText: 'Jurusan'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('— belum —')),
                  ..._jurusan.map((j) => DropdownMenuItem(
                      value: '${j['id']}', child: Text('${j['singkatan']} — ${j['nama']}'))),
                ],
                onChanged: (v) => setSt(() => jurusanId = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(
              onPressed: () async {
                if (namaCtrl.text.trim().isEmpty) return;
                final n = namaCtrl.text.trim().toUpperCase();
                final t = tingkat;
                final data = {
                  'nama': n,
                  'tingkat': _tingkatNum(t),
                  'jurusan_id': jurusanId,
                };
                try {
                  if (row == null) {
                    await Api.client.from('kelas').insert(data);
                  } else {
                    await Api.client
                        .from('kelas')
                        .update(data)
                        .eq('id', row['id']);
                    // sinkronkan jurusan utk anggota rombel ikut (opsional tidak)
                  }
                  if (c.mounted) Navigator.pop(c, true);
                } catch (e) {
                  if (c.mounted) {
                    ScaffoldMessenger.of(c).showSnackBar(
                        SnackBar(content: Text('Gagal: $e')));
                  }
                }
              },
              child: const Text('Simpan')),
        ],
      ),
    );
    if (ok == true) _load();
  }

  int? _tingkatNum(String? t) =>
      switch (t) { 'X' => 10, 'XI' => 11, 'XII' => 12, _ => null };

  String _label(Map<String, dynamic> k) {
    final j = _singkatan(k);
    return j.isEmpty ? '${k['nama']}' : '${k['nama']}  •  $j';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Kelas / Rombel'),
        actions: [
          IconButton(
              tooltip: 'Kelola tabel kelas (CSV-like CRUD)',
              icon: const Icon(Icons.table_view_outlined),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CrudKelasScreen()))),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        onPressed: () => _form(),
        icon: const Icon(Icons.add),
        label: const Text('Rombel'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      for (final t in _tingkats)
                        Card(
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          child: ExpansionTile(
                            initiallyExpanded: true,
                            shape: const Border(),
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primary.withOpacity(0.12),
                              child: Text(t,
                                  style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontWeight: FontWeight.bold)),
                            ),
                            title: Text('Kelas $t',
                                style: const TextStyle(
                                    fontSize: 15.5, fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                '${_rombelOf(t).fold<int>(0, (a, k) => a + _anggota("${k['id']}").length)} siswa • ${_rombelOf(t).length} rombel'),
                            children: [
                              for (final k in _rombelOf(t))
                                _rombelTile(k),
                            ],
                          ),
                        ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }

  Widget _rombelTile(Map<String, dynamic> k) {
    final ang = _anggota('${k['id']}');
    final j = _singkatan(k);
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        dense: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Badge(
          isLabelVisible: j.isNotEmpty,
          label: Text(j,
              style: const TextStyle(fontSize: 9, color: Colors.white)),
          backgroundColor: j == 'TKJ'
              ? AppTheme.primary
              : j == 'TSM'
                  ? AppTheme.accent
                  : AppTheme.secondary,
          child: const Icon(Icons.groups_outlined, color: Color(0xFF0F172A)),
        ),
        title: Text('${k['nama']}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text('${ang.length} siswa terdata',
            style: const TextStyle(fontSize: 11)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: () => _form(row: k)),
            IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppTheme.danger),
                onPressed: () async {
                  if (ang.isNotEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Rombel berisi siswa — pindahkan dulu')));
                    }
                    return;
                  }
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('Hapus rombel?'),
                      content: Text('${k['nama']}'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Batal')),
                        FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.danger),
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Hapus')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await Api.client
                        .from('kelas')
                        .delete()
                        .eq('id', k['id']);
                    _load();
                  }
                }),
          ],
        ),
        children: [
          if (ang.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('Belum ada siswa — import lewat Data Master → Import Siswa',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey)),
            )
          else
            for (final (i, s) in ang.indexed)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.fromLTRB(24, 0, 12, 0),
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      '${s['jenis_kelamin']}' == 'L'
                          ? const Color(0xFFDBEAFE)
                          : const Color(0xFFFCE7F3),
                  child: Text('${i + 1}',
                      style: const TextStyle(fontSize: 10.5)),
                ),
                title: Text('${s['nama']}',
                    style: const TextStyle(fontSize: 13)),
                subtitle: Text('NIS ${s['nis']}',
                    style: const TextStyle(fontSize: 11)),
                trailing: s['aktive_ok'] == false
                    ? const Text('NONAKTIF',
                        style:
                            TextStyle(fontSize: 10, color: AppTheme.danger))
                    : null,
              ),
        ],
      ),
    );
  }
}

String kelasTingkat(String nama) {
  final t = nama.trim().toUpperCase();
  if (t.startsWith('XII')) return 'XII';
  if (t.startsWith('XI') && !t.startsWith('XII')) return 'XI';
  if (t.startsWith('X')) return 'X';
  final m = RegExp(r'^(\d+)').firstMatch(t);
  if (m != null) {
    switch (m.group(1)) {
      case '10': return 'X';
      case '11': return 'XI';
      case '12': return 'XII';
    }
  }
  return t.isEmpty ? 'Lain' : 'Kelas ${t.split(RegExp(r'\s')).first}';
}

String? namaTingkatFromStr(String nama) {
  final t = kelasTingkat(nama);
  return ['X', 'XI', 'XII'].contains(t) ? t : null;
}
