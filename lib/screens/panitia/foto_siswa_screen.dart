import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../services/api.dart';
import '../../widgets/state_views.dart';

class FotoSiswaScreen extends StatefulWidget {
  const FotoSiswaScreen({super.key});

  @override
  State<FotoSiswaScreen> createState() => _FotoSiswaScreenState();
}

class _FotoSiswaScreenState extends State<FotoSiswaScreen> {
 List<Map<String, dynamic>> _siswaList = [];
 List<Map<String, dynamic>> _jurusanList = [];
 List<Map<String, dynamic>> _kelasList = [];
 String? _selectedJurusanId;
 String? _selectedKelasId;
  bool _loading = true;
  String? _error;
  bool _uploading = false;
  String? _activeSiswaId;

  @override
  void initState() {
    super.initState();
    _loadJurusanKelas();
    _load();
  }

  Future<void> _loadJurusanKelas() async {
    try {
      final j = await Api.client.from('jurusan').select('id,nama,singkatan').order('nama');
      final k = await Api.client.from('kelas').select('id,nama,jurusan_id').order('nama');
      if (!mounted) return;
      setState(() {
        _jurusanList = List<Map<String, dynamic>>.from(j);
        _kelasList = List<Map<String, dynamic>>.from(k);
      });
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var query = Api.client
          .from('siswa')
          .select('id,nama,nis,foto_url,kelas_id,kelas(nama,jurusan(nama,singkatan))');
      final all = await query.order('nis');
      if (!mounted) return;

      List<Map<String, dynamic>> filtered = List<Map<String, dynamic>>.from(all);

      // Filter jurusan
      if (_selectedJurusanId != null && _selectedJurusanId!.isNotEmpty) {
        final kelasIdsForJurusan = _kelasList
            .where((k) => k['jurusan_id'] == _selectedJurusanId)
            .map((k) => k['id'])
            .toSet();
        filtered = filtered
            .where((s) => kelasIdsForJurusan.contains(s['kelas_id']))
            .toList();
      }

      // Filter kelas
      if (_selectedKelasId != null && _selectedKelasId!.isNotEmpty) {
        filtered = filtered
            .where((s) => s['kelas_id'] == _selectedKelasId)
            .toList();
      }

      setState(() {
        _siswaList = filtered;
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

  Future<void> _uploadFoto(Map<String, dynamic> siswa) async {
    setState(() => _uploading = true);
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Pilih foto untuk ${siswa['nama']}',
        type: FileType.image,
      );
      final file = result.first;
      final path = file.path!;
      final fileName =
          'siswa_${siswa['id']}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final bytes = await File(path).readAsBytes();
      final storage = Api.client.storage.from('foto_siswa');
      await storage.uploadBinary(
        fileName,
        bytes,
        fileOptions: FileOptions(contentType: 'image/jpeg'),
      );
      if (!mounted) return;
      final url = Api.client.storage.from('foto_siswa').getPublicUrl(fileName);

      await Api.client
          .from('siswa')
          .update({'foto_url': url})
          .eq('id', siswa['id']);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Foto ${siswa['nama']} berhasil diupload'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal upload: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Upload Foto Siswa'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    return Column(
      children: [
        // ── Filter JURUSAN + KELAS ──────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedJurusanId,
                  decoration: const InputDecoration(
                    labelText: 'Jurusan',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                        value: null, child: Text('Semua Jurusan')),
                    ..._jurusanList.map((j) => DropdownMenuItem<String>(
                          value: j['id'] as String?,
                          child: Text(j['nama']?.toString() ?? j['id']?.toString() ?? ''),
                        )),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _selectedJurusanId = v;
                      _selectedKelasId = null; // reset kelas saat ganti jurusan
                    });
                    _load();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedKelasId,
                  decoration: const InputDecoration(
                    labelText: 'Kelas',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                        value: null, child: Text('Semua Kelas')),
                    ..._kelasList
                        .where((k) =>
                            _selectedJurusanId == null ||
                            k['jurusan_id'] == _selectedJurusanId)
                        .map((k) => DropdownMenuItem<String>(
                              value: k['id'] as String?,
                              child: Text(k['nama']?.toString() ?? ''),
                            )),
                  ],
                  onChanged: (v) {
                    setState(() => _selectedKelasId = v);
                    _load();
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── Daftar siswa ────────────────────────────────────
        Expanded(
          child: _siswaList.isEmpty
              ? const Center(
                  child: Text('Tidak ada siswa',
                      style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _siswaList.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final s = _siswaList[i];
                    final kelasMap =
                        s['kelas'] is Map ? s['kelas'] as Map : {};
                    final kelas = kelasMap['nama'] as String?;
                    final jurusanMap =
                        kelasMap['jurusan'] is Map ? kelasMap['jurusan'] as Map : {};
                    final jurusan =
                        jurusanMap['nama'] as String?;
                    final fotoUrl = s['foto_url'] as String?;
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundImage: (fotoUrl != null &&
                                  fotoUrl.isNotEmpty)
                              ? NetworkImage(fotoUrl)
                              : null,
                          child: (fotoUrl != null && fotoUrl.isNotEmpty)
                              ? null
                              : const Icon(Icons.person_outline, size: 24),
                        ),
                        title: Text(s['nama'] ?? '',
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            'NIS: ${s['nis'] ?? '-'}'
                            '${kelas != null ? ' • $kelas' : ''}'
                            '${jurusan != null ? ' • $jurusan' : ''}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_uploading && s['id'] == _activeSiswaId)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              TextButton.icon(
                                onPressed: _uploading ? null : () {
                                  setState(() => _activeSiswaId = s['id']);
                                  _uploadFoto(s);
                                },
                                icon: Icon(
                                  fotoUrl != null
                                      ? Icons.photo_library
                                      : Icons.add_a_photo,
                                  size: 18,
                                ),
                                label: Text(
                                    fotoUrl != null ? 'Ganti' : 'Upload'),
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
