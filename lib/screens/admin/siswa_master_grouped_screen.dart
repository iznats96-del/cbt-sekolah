import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../../widgets/crud_screen.dart';
import '../../widgets/state_views.dart';

class SiswaMasterGroupedScreen extends StatefulWidget {
  const SiswaMasterGroupedScreen({super.key});
  @override
  State<SiswaMasterGroupedScreen> createState() => _SiswaMasterGroupedScreenState();
}

class _SiswaMasterGroupedScreenState extends State<SiswaMasterGroupedScreen> {
  List<Map<String, dynamic>> _kelas = [];
  List<Map<String, dynamic>> _jurusan = [];
  List<Map<String, dynamic>> _siswa = [];
  String _q = '';
  String _filterJurusan = '';
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
        Api.client.from('kelas').select('id,nama,tingkat,jurusan_id,jurusan(singkatan,nama)').order('nama'),
        Api.client.from('jurusan').select('id,nama,singkatan').order('singkatan'),
        Api.client.from('siswa').select('id,nis,nisn,nama,nomor_peserta,jenis_kelamin,kelas_id,aktive_ok').order('nama').limit(3000),
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

  // kelompok: jurusan -> kelas -> siswa
  Map<String, Map<String, List<Map<String, dynamic>>>> get _grouped {
    final out = <String, Map<String, List<Map<String, dynamic>>>>{};
    final q = _q.trim().toLowerCase();
    for (final s in _siswa) {
      if (q.isNotEmpty) {
        final hay = '${s['nama'] ?? ''} ${s['nis'] ?? ''} ${s['nomor_peserta'] ?? ''}'.toLowerCase();
        if (!hay.contains(q)) continue;
      }
      final k = _kelas.firstWhere((e) => '${e['id']}' == '${s['kelas_id']}', orElse: () => <String, dynamic>{});
      final j = k['jurusan'];
      final js = j is Map && j['singkatan'] != null ? '${j['singkatan']}' : 'TANPA JURUSAN';
      if (_filterJurusan.isNotEmpty && js != _filterJurusan) continue;
      final kn = k['nama']?.toString() ?? 'TANPA KELAS';
      (out[js] ??= {})[kn] ??= [];
      out[js]![kn]!.add(s);
    }
    return out;
  }

  String _kelasLabel(Map<String, dynamic> k) {
    final j = k['jurusan'];
    final js = j is Map ? '${j['singkatan'] ?? ''}' : '';
    return js.isEmpty ? '${k['nama']}' : '${k['nama']} • $js';
  }

  Future<void> _openForm({Map<String, dynamic>? row}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _SiswaFormDialog(initial: row, kelas: _kelas, jurusan: _jurusan),
    );
    if (result == null) return;
    try {
      if (row != null) {
        await Api.client.from('siswa').update(result).eq('id', row['id']);
      } else {
        // NIS wajib, nama wajib
        await Api.client.from('siswa').insert(result);
      }
      _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tersimpan'), backgroundColor: AppTheme.secondary));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: AppTheme.danger));
    }
  }

  Future<void> _hapus(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus siswa?'),
        content: Text('${row['nama']} (${row['nis']})'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppTheme.danger), onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.client.from('siswa').delete().eq('id', row['id']);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: AppTheme.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: const Text('Siswa — per Kelas dan Jurusan')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        onPressed: () => _openForm(),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Tambah'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: (v) => setState(() => _q = v),
                              decoration: const InputDecoration(
                                hintText: 'Cari nama / NIS / nomor',
                                isDense: true,
                                prefixIcon: Icon(Icons.search, size: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 150,
                            child: DropdownButtonFormField<String>(
                              initialValue: _filterJurusan.isEmpty ? null : _filterJurusan,
                              decoration: const InputDecoration(isDense: true, hintText: 'Jurusan'),
                              borderRadius: BorderRadius.circular(12),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Semua Jurusan', style: TextStyle(fontSize: 12))),
                                ..._jurusan.map((j) => DropdownMenuItem(value: '${j['singkatan']}', child: Text('${j['singkatan']} — ${j['nama']}', style: const TextStyle(fontSize: 12)))),
                              ],
                              onChanged: (v) => setState(() => _filterJurusan = v ?? ''),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Row(
                        children: [
                          _mini('${_siswa.length} siswa', AppTheme.primary),
                          const SizedBox(width: 6),
                          _mini('${_kelas.length} rombel', Colors.grey),
                          const SizedBox(width: 6),
                          _mini('${_jurusan.length} jurusan', AppTheme.secondary),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: _grouped.isEmpty
                            ? const Center(child: Text('Tidak ada siswa sesuai filter', style: TextStyle(color: Colors.grey)))
                            : ListView(
                                padding: const EdgeInsets.all(8),
                                children: [
                                  for (final j in (_grouped.keys.toList()..sort())) _jurusanCard(j, _grouped[j]!),
                                  const SizedBox(height: 80),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _jurusanCard(String jurusan, Map<String, List<Map<String, dynamic>>> byKelas) {
    final total = byKelas.values.fold<int>(0, (a, b) => a + b.length);
    final kelasNames = byKelas.keys.toList()..sort();
    final color = jurusan == 'TKJ'
        ? AppTheme.primary
        : jurusan == 'TSM'
            ? AppTheme.accent
            : jurusan == 'AKL'
                ? AppTheme.secondary
                : Colors.grey;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const Border(),
        leading: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Text(jurusan, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
        ),
        title: Text(jurusan, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$total siswa • ${byKelas.length} rombel', style: const TextStyle(fontSize: 12, color: Colors.grey)),
        children: [
          for (final kn in kelasNames) _kelasTile(kn, byKelas[kn]!),
        ],
      ),
    );
  }

  Widget _kelasTile(String kelasNama, List<Map<String, dynamic>> list) {
    list.sort((a, b) => '${a['nama']}'.compareTo('${b['nama']}'));
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        dense: true,
        title: Text(kelasNama, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text('${list.length} siswa', style: const TextStyle(fontSize: 11, color: Colors.grey)),
        children: [
          for (int i = 0; i < list.length; i++) _siswaRow(i + 1, list[i]),
        ],
      ),
    );
  }

  Widget _siswaRow(int no, Map<String, dynamic> s) {
    final nomor = '${s['nomor_peserta'] ?? ''}';
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.fromLTRB(24, 0, 8, 0),
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: const Color(0xFFEAF3FB),
        child: Text('$no', style: const TextStyle(fontSize: 10, color: AppTheme.primary)),
      ),
      title: Text('${s['nama']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NIS ${s['nis'] ?? '-'}${nomor.isNotEmpty ? ' • $nomor' : ''}', style: const TextStyle(fontSize: 11)),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (nomor.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.copy_outlined, size: 16, color: AppTheme.primary),
              tooltip: 'Salin nomor',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: nomor));
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nomor tersalin'), backgroundColor: AppTheme.secondary));
              },
            ),
          IconButton(icon: const Icon(Icons.edit_outlined, size: 16), onPressed: () => _openForm(row: s)),
          IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.danger), onPressed: () => _hapus(s)),
        ],
      ),
    );
  }

  Widget _mini(String t, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
      child: Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c)),
    );
  }
}

class _SiswaFormDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final List<Map<String, dynamic>> kelas;
  final List<Map<String, dynamic>> jurusan;
  const _SiswaFormDialog({this.initial, required this.kelas, required this.jurusan});
  @override
  State<_SiswaFormDialog> createState() => _SiswaFormDialogState();
}

class _SiswaFormDialogState extends State<_SiswaFormDialog> {
  late final _nis = TextEditingController(text: widget.initial?['nis']?.toString() ?? '');
  late final _nisn = TextEditingController(text: widget.initial?['nisn']?.toString() ?? '');
  late final _nama = TextEditingController(text: widget.initial?['nama']?.toString() ?? '');
  String? _jk;
  String? _kelasId;
  bool _aktif = true;

  @override
  void initState() {
    super.initState();
    _jk = widget.initial?['jenis_kelamin']?.toString();
    _kelasId = widget.initial?['kelas_id']?.toString();
    _aktif = widget.initial?['aktive_ok'] != false;
  }

  @override
  void dispose() {
    _nis.dispose();
    _nisn.dispose();
    _nama.dispose();
    super.dispose();
  }

  void _save() {
    if (_nis.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('NIS wajib'), backgroundColor: AppTheme.danger));
      return;
    }
    if (_nama.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama wajib'), backgroundColor: AppTheme.danger));
      return;
    }
    Navigator.pop(context, {
      'nis': _nis.text.trim(),
      'nisn': _nisn.text.trim().isEmpty ? null : _nisn.text.trim(),
      'nama': _nama.text.trim(),
      'jenis_kelamin': _jk,
      'kelas_id': _kelasId,
      'aktive_ok': _aktif,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Tambah Siswa' : 'Edit Siswa'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _nis, decoration: const InputDecoration(labelText: 'NIS *')),
            const SizedBox(height: 10),
            TextField(controller: _nisn, decoration: const InputDecoration(labelText: 'NISN')),
            const SizedBox(height: 10),
            TextField(controller: _nama, decoration: const InputDecoration(labelText: 'Nama *')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _jk,
              decoration: const InputDecoration(labelText: 'Jenis Kelamin'),
              items: const [DropdownMenuItem(value: 'L', child: Text('Laki-laki')), DropdownMenuItem(value: 'P', child: Text('Perempuan'))],
              onChanged: (v) => setState(() => _jk = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _kelasId,
              decoration: const InputDecoration(labelText: 'Kelas / Rombel'),
              borderRadius: BorderRadius.circular(12),
              items: [
                const DropdownMenuItem(value: null, child: Text('— tanpa kelas —')),
                ...widget.kelas.map((k) => DropdownMenuItem(value: '${k['id']}', child: Text('${k['nama']}', style: const TextStyle(fontSize: 13)))),
              ],
              onChanged: (v) => setState(() => _kelasId = v),
            ),
            const SizedBox(height: 10),
            SwitchListTile(value: _aktif, onChanged: (v) => setState(() => _aktif = v), title: const Text('Aktif')),
            if (widget.initial?['nomor_peserta'] != null && '${widget.initial!['nomor_peserta']}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Nomor: ${widget.initial!['nomor_peserta']}', style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(onPressed: _save, child: const Text('Simpan')),
      ],
    );
  }
}
