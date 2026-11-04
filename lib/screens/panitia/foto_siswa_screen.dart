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
  bool _loading = true;
  String? _error;
  bool _uploading = false;
  String? _activeSiswaId;

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
          .from('siswa')
          .select('id,nama,nis,foto_url,kelas(nama)')
          .order('nis');
      if (!mounted) return;
      setState(() {
        _siswaList = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat siswa: $e';
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
      if (result == null || result.isEmpty) {
        setState(() => _uploading = false);
        return;
      }
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
    if (_siswaList.isEmpty) {
      return const Center(
          child: Text('Tidak ada siswa',
              style: TextStyle(color: Colors.grey)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _siswaList.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final s = _siswaList[i];
        final kelas = s['kelas'] is Map ? (s['kelas'] as Map)['nama'] : null;
        final fotoUrl = s['foto_url'] as String?;
        return Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              radius: 24,
              backgroundImage:
                  (fotoUrl != null && fotoUrl.isNotEmpty) ? NetworkImage(fotoUrl) : null,
              child: (fotoUrl != null && fotoUrl.isNotEmpty)
                  ? null
                  : const Icon(Icons.person_outline, size: 24),
            ),
            title: Text(s['nama'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle:
                Text('NIS: ${s['nis'] ?? '-'}${kelas != null ? ' • $kelas' : ''}'),
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
                      fotoUrl != null ? Icons.photo_library : Icons.add_a_photo,
                      size: 18,
                    ),
                    label: Text(fotoUrl != null ? 'Ganti' : 'Upload'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
