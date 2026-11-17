import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../../widgets/dashboard_header.dart';

const _hari = <int, String>{
  1: 'Senin', 2: 'Selasa', 3: 'Rabu', 4: 'Kamis', 5: 'Jumat', 6: 'Sabtu',
};

class JadwalPelajaranScreen extends StatefulWidget {
  const JadwalPelajaranScreen({super.key});

  @override
  State<JadwalPelajaranScreen> createState() => _JadwalPelajaranScreenState();
}

class _JadwalPelajaranScreenState extends State<JadwalPelajaranScreen> {
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _kelas = [];
  List<Map<String, dynamic>> _mapel = [];
  bool _loading = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final res = await Future.wait([
        Api.client.from('jadwal_mapel').select(
            '*,kelas(nama),mata_pelajaran(nama),profiles(nama)')
            .order('kelas_id')
            .order('hari')
            .order('jam_mulai'),
        Api.client.from('kelas').select('id,nama').order('nama'),
        Api.client.from('mata_pelajaran').select('id,nama').order('nama'),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(res[0]);
        _kelas = List<Map<String, dynamic>>.from(res[1]);
        _mapel = List<Map<String, dynamic>>.from(res[2]);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _form({Map<String, dynamic>? row}) async {
    String? kelasId = row?['kelas_id']?.toString();
    String? mapelId = row?['mapel_id']?.toString();
    int hari = (row?['hari'] as num?)?.toInt() ?? 1;
    final mulaiC =
        TextEditingController(text: row?['jam_mulai']?.toString().substring(0, 5) ?? '07:30');
    final selesaiC =
        TextEditingController(text: row?['jam_selesai']?.toString().substring(0, 5) ?? '08:40');
    final ketC = TextEditingController(text: row?['keterangan']?.toString() ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(row == null ? 'Tambah Jadwal' : 'Edit Jadwal'),
        content: StatefulBuilder(
          builder: (c, setSt) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: kelasId,
                  borderRadius: BorderRadius.circular(12),
                  decoration: const InputDecoration(labelText: 'Rombel *'),
                  items: _kelas
                      .map((k) => DropdownMenuItem(
                          value: '${k['id']}', child: Text('${k['nama']}')))
                      .toList(),
                  onChanged: (v) => setSt(() => kelasId = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: mapelId,
                  borderRadius: BorderRadius.circular(12),
                  decoration: const InputDecoration(labelText: 'Mata Pelajaran *'),
                  items: _mapel
                      .map((m) => DropdownMenuItem(
                          value: '${m['id']}', child: Text('${m['nama']}')))
                      .toList(),
                  onChanged: (v) => setSt(() => mapelId = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: hari,
                  borderRadius: BorderRadius.circular(12),
                  decoration: const InputDecoration(labelText: 'Hari *'),
                  items: _hari.entries
                      .map((e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onChanged: (v) => setSt(() => hari = v ?? 1),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: mulaiC,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9:]')),
                        ],
                        decoration: const InputDecoration(
                            labelText: 'Jam mulai *', hintText: '07:30'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: selesaiC,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9:]')),
                        ],
                        decoration: const InputDecoration(
                            labelText: 'Jam selesai *', hintText: '08:40'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: ketC,
                  decoration: const InputDecoration(
                      labelText: 'Keterangan (opsional)'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () async {
                if (kelasId == null ||
                    mapelId == null ||
                    !RegExp(r'^\d{1,2}:\d{2}$')
                            .hasMatch(mulaiC.text) ||
                    !RegExp(r'^\d{1,2}:\d{2}$')
                        .hasMatch(selesaiC.text)) {
                  ScaffoldMessenger.of(c).showSnackBar(const SnackBar(
                      content: Text(
                          'Lengkapi rombel/mapel + jam format HH:MM'),
                      backgroundColor: AppTheme.danger));
                  return;
                }
                final data = {
                  'kelas_id': kelasId,
                  'mapel_id': mapelId,
                  'hari': hari,
                  'jam_mulai': mulaiC.text.trim(),
                  'jam_selesai': selesaiC.text.trim(),
                  'keterangan':
                      ketC.text.trim().isEmpty ? null : ketC.text.trim(),
                };
                try {
                  if (row != null) {
                    await Api.client
                        .from('jadwal_mapel')
                        .update(data)
                        .eq('id', row['id']);
                  } else {
                    await Api.client.from('jadwal_mapel').insert(data);
                  }
                  if (c.mounted) Navigator.pop(c, true);
                } catch (e) {
                  if (c.mounted) {
                    ScaffoldMessenger.of(c).showSnackBar(SnackBar(
                        content: Text('Gagal: $e'),
                        backgroundColor: AppTheme.danger));
                  }
                }
              },
              child: const Text('Simpan')),
        ],
      ),
    );
    if (ok == true) _load();
  }

  Future<void> _hapus(Map<String, dynamic> r) async {
    final o = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus jadwal?'),
        content: Text('${r['kelas']?['nama']} • ${_hari[r['hari']]} ${r['jam_mulai']}'),
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
    if (o != true) return;
    try {
      await Api.client.from('jadwal_mapel').delete().eq('id', r['id']);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: const DashboardHeader(
        title: 'JADWAL PELAJARAN',
        showBack: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: () => _form(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err != null
              ? Center(child: Text(_err!))
              : _rows.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.date_range, size: 56, color: Colors.grey),
                          const SizedBox(height: 10),
                          const Text('Belum ada jadwal pelajaran',
                              style: TextStyle(color: Colors.grey)),
                          const Text('Contoh: X AKA 1 • Senin • 07:30-08:40 • Produktif TKJ 2',
                              style: TextStyle(fontSize: 11, color: Colors.grey)),
                          const SizedBox(height: 10),
                          FilledButton(onPressed: () => _form(), child: const Text('+ Buat Jadwal')),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _rows.length,
                        itemBuilder: (c, i) {
                          final r = _rows[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                                child: Text('${(_hari[r['hari']] ?? '?').substring(0, 1)}',
                                    style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.bold)),
                              ),
                              title: Text(
                                  '${r['kelas']?['nama']} • ${_hari[r['hari']]}',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                  '${r['jam_mulai'].toString().substring(0, 5)}–'
                                  '${r['jam_selesai'].toString().substring(0, 5)}  •  '
                                  '${r['mata_pelajaran']?['nama'] ?? ''}',
                                  style: const TextStyle(
                                      fontSize: 12.5)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      onPressed: () => _form(row: r)),
                                  IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          color: AppTheme.danger),
                                      onPressed: () => _hapus(r)),
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

