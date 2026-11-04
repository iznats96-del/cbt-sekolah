import 'package:flutter/material.dart';

import '../../services/api.dart';
import '../../widgets/state_views.dart';

class AturJadwalPanitiaScreen extends StatefulWidget {
  final String ujianId;
  final String ujianNama;

  const AturJadwalPanitiaScreen({
    super.key,
    required this.ujianId,
    required this.ujianNama,
  });

  @override
  State<AturJadwalPanitiaScreen> createState() =>
      _AturJadwalPanitiaScreenState();
}

class _AturJadwalPanitiaScreenState extends State<AturJadwalPanitiaScreen> {
  List<Map<String, dynamic>> _kelasList = [];
  List<Map<String, dynamic>> _sesiList = [];
  List<Map<String, dynamic>> _ruangList = [];
  Map<String, String?> _selectedSesi = {};
  Map<String, String?> _selectedRuang = {};
  bool _loading = true;
  bool _saving = false;
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
      final kelasRes = await Api.client
          .from('kelas')
          .select('id,nama,jurusan(nama)')
          .order('nama');
      final sesiRes =
          await Api.client.from('sesi').select('id,nama').order('nama');
      final ruangRes =
          await Api.client.from('ruang').select('id,nama').order('nama');
      final existingRes = await Api.client
          .from('atur_ruang_sesi')
          .select('kelas_id,sesi_id,ruang_id')
          .eq('ujian_id', widget.ujianId);

      if (!mounted) return;
      setState(() {
        _kelasList = List<Map<String, dynamic>>.from(kelasRes);
        _sesiList = List<Map<String, dynamic>>.from(sesiRes);
        _ruangList = List<Map<String, dynamic>>.from(ruangRes);

        for (final k in _kelasList) {
          final kid = k['id'] as String;
          final match = existingRes.firstWhere(
            (e) => e['kelas_id'] == kid,
            orElse: () => <String, dynamic>{},
          );
          _selectedSesi[kid] = match['sesi_id'] as String?;
          _selectedRuang[kid] = match['ruang_id'] as String?;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat data: $e';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // Delete existing assignments for this ujian
      await Api.client
          .from('atur_ruang_sesi')
          .delete()
          .eq('ujian_id', widget.ujianId);

      // Insert new assignments
      final inserts = <Map<String, dynamic>>[];
      for (final k in _kelasList) {
        final kid = k['id'] as String;
        final sid = _selectedSesi[kid];
        final rid = _selectedRuang[kid];
        if (sid != null && rid != null) {
          inserts.add({
            'ujian_id': widget.ujianId,
            'kelas_id': kid,
            'sesi_id': sid,
            'ruang_id': rid,
          });
        }
      }

      if (inserts.isNotEmpty) {
        await Api.client.from('atur_ruang_sesi').insert(inserts);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${inserts.length} jadwal berhasil disimpan'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text('Atur Jadwal: ${widget.ujianNama}'),
        actions: [
          if (!_loading && !_saving)
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text('Simpan',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_kelasList.isEmpty) {
      return const Center(
          child: Text('Tidak ada kelas tersedia',
              style: TextStyle(color: Colors.grey)));
    }
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: const Color(0xFFE3F2FD),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: Color(0xFF1A6DB4)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pilih sesi & ruang untuk setiap kelas. Kelas tanpa assignment tidak akan muncul di jadwal ujian.',
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey[700]),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _kelasList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final k = _kelasList[i];
              final kid = k['id'] as String;
              final jurusan = k['jurusan'];
              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        k['nama'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (jurusan is Map)
                        Text(
                          'Jurusan: ${jurusan['nama'] ?? '-'}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey),
                        ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedSesi[kid],
                        decoration: const InputDecoration(
                          labelText: 'Sesi',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: _sesiList
                            .map((s) => DropdownMenuItem(
                                  value: s['id'] as String,
                                  child: Text(s['nama'] ?? ''),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedSesi[kid] = v),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _selectedRuang[kid],
                        decoration: const InputDecoration(
                          labelText: 'Ruang',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: _ruangList
                            .map((r) => DropdownMenuItem(
                                  value: r['id'] as String,
                                  child: Text(r['nama'] ?? ''),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedRuang[kid] = v),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}