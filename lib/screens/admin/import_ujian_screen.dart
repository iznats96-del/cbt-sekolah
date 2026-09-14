import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../../services/ujian_docx_parser.dart';

/// Import satu berkas DOCX -> mapel + bank soal + ujian (draft) dibuat sekaligus.
class ImportUjianScreen extends StatefulWidget {
  const ImportUjianScreen({super.key});

  @override
  State<ImportUjianScreen> createState() => _ImportUjianScreenState();
}

class _ImportUjianScreenState extends State<ImportUjianScreen> {
  UjianDocx? _doc;
  bool _parsing = false;
  bool _importing = false;
  String? _error;

  final _mapelCtrl = TextEditingController();
  final _kelasCtrl = TextEditingController();
  final _judulCtrl = TextEditingController();
  final _waktuCtrl = TextEditingController(text: '60');
  final _tokenCtrl = TextEditingController();
  String? _fileName;

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx', 'dotx'],
    );
    if (files.isEmpty) return;
    final f = files.first;
    setState(() {
      _parsing = true;
      _error = null;
      _fileName = f.name;
      _doc = null;
    });
    try {
      final bytes = await f.readAsBytes();
      final doc = UjianDocxParser.parse(bytes);
      if (!mounted) return;
      setState(() {
        _doc = doc;
        _mapelCtrl.text = doc.mapel;
        _kelasCtrl.text = doc.kelas;
        _judulCtrl.text = doc.judul;
        _waktuCtrl.text = '${doc.waktuMenit ?? 60}';
        _tokenCtrl.text = '';
        _parsing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal membaca docx: $e';
        _parsing = false;
      });
    }
  }

  Future<String?> _uploadImage(String path, Uint8List bytes) async {
    try {
      final ext = path.split('.').last.toLowerCase();
      final p = 'soal/import_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await Api.client.storage.from('soal').uploadBinary(
        p, bytes,
        fileOptions: FileOptions(
            contentType: ext == 'png' ? 'image/png' : 'image/jpeg', upsert: true),
      );
      return Api.client.storage.from('soal').getPublicUrl(p);
    } catch (_) {
      return null;
    }
  }

  Future<void> _import() async {
    final doc = _doc;
    if (doc == null) return;
    setState(() => _importing = true);
    try {
      final items = <Map<String, dynamic>>[];
      for (final p in doc.pg) {
        dynamic kunci;
        if (p.kunci != null) {
          final idx = p.kunci!.codeUnitAt(0) - 65;
          final opsiTxt = (idx >= 0 && idx < p.opsi.length) ? p.opsi[idx] : null;
          kunci = {'index': idx, if (opsiTxt != null) 'jawaban': opsiTxt};
        }
        String? img;
        if (p.imgPath != null && doc.images.containsKey(p.imgPath)) {
          img = await _uploadImage(p.imgPath!, doc.images[p.imgPath]!);
        }
        items.add({
          'jenis': 'pg',
          'soal': p.soal,
          'opsi': p.opsi,
          'kunci': kunci,
          if (img != null) 'gambar_url': img,
          'bobot': '1',
        });
      }
      for (final j in doc.jodoh) {
        items.add({
          'jenis': 'jodoh',
          'soal': j.soal,
          'opsi': j.opsi.map((o) => o.replaceFirst(RegExp(r'^[A-J][.)]\s*'), '').trim()).toList(),
          'kunci': null,
          'bobot': '1',
        });
      }
      for (final e in doc.essay) {
        items.add({
          'jenis': 'essay',
          'soal': e.soal,
          'opsi': null,
          'kunci': null,
          'bobot': '1',
        });
      }

      final payload = <String, dynamic>{
        'mapel': _mapelCtrl.text.trim(),
        'jurusan': doc.jurusan ?? '',
        'kelas': _kelasCtrl.text.trim(),
        'judul': _judulCtrl.text.trim(),
        'waktu': _waktuCtrl.text.trim(),
        'token': _tokenCtrl.text.trim(),
        'jenis_ujian': 'Penilaian Sumatif',
        'guru': doc.guru,
        'items': items,
      };
      final res = await Api.client.rpc('admin_import_ujian_docx', params: payload);
      final map = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Ujian Berhasil Diimpor 🎉'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mapel: ${map['mapel']}'),
              Text('Kelas: ${map['kelas']}'),
              Text('Soal masuk: ${map['soal_count']}'),
              Text('Token: ${map['token']}'),
              const SizedBox(height: 8),
              const Text('Status DRAFT — atur tanggal/sesi lalu aktifkan di menu Ujian.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          actions: [
            FilledButton(
                onPressed: () {
                  Navigator.pop(c);
                  Navigator.pop(context, true);
                },
                child: const Text('OK')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Gagal impor: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: const Text('Import Ujian dari DOCX')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Format: naskah ujian sekolah (.docx) yang berisi kop, "Mata Pelajaran:", '
                    '"Kelas/Kompetensi keahlian:", "Waktu: 60 menit", sesi "PILIHAN GANDA" '
                    '(opsi a. A. ... s.d. e. E.), "MENJODOHKAN", "C. Essay", dan '
                    '"KUNCI JAWABAN" (1. B, dst).',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _parsing ? null : _pickFile,
                    icon: _parsing
                        ? const SizedBox(height: 16, width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.description_outlined),
                    label: const Text('Pilih file .docx'),
                  ),
                  if (_fileName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('$_fileName',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              color: AppTheme.danger.withOpacity(0.06),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.danger),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error!,
                            style: const TextStyle(color: AppTheme.danger, fontSize: 12))),
                  ],
                ),
              ),
            ),
          ],
          if (doc != null) ...[
            const SizedBox(height: 12),
            for (final w in doc.warnings)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: Colors.orange.withOpacity(0.08),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  title: Text(w, style: const TextStyle(fontSize: 12)),
                ),
              ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('HASIL DETEKSI', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, children: [
                      Chip(label: Text('${doc.pg.length} PG'), avatar: const Icon(Icons.radio_button_checked, size: 16)),
                      Chip(label: Text('${doc.jodoh.length} Jodoh'), avatar: const Icon(Icons.link, size: 16)),
                      Chip(label: Text('${doc.essay.length} Essay'), avatar: const Icon(Icons.edit_note, size: 16)),
                      if (doc.images.isNotEmpty)
                        Chip(label: Text('${doc.images.length} gambar'), avatar: const Icon(Icons.image, size: 16)),
                    ]),
                    const SizedBox(height: 16),
                    TextField(controller: _mapelCtrl, decoration: const InputDecoration(labelText: 'Mata Pelajaran *')),
                    const SizedBox(height: 12),
                    TextField(controller: _kelasCtrl, decoration: const InputDecoration(labelText: 'Kelas *')),
                    const SizedBox(height: 12),
                    TextField(controller: _judulCtrl, decoration: const InputDecoration(labelText: 'Judul Ujian')),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _waktuCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Alokasi (menit)'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _tokenCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(labelText: 'Token (kosong=auto)'),
                          ),
                        ),
                      ],
                    ),
                    if (doc.guru.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Guru terdeteksi: ${doc.guru} • ${doc.jurusan ?? ''}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (doc.pg.isNotEmpty)
              Card(
                margin: EdgeInsets.zero,
                child: ExpansionTile(
                  title: Text('Pratinjau ${doc.pg.length} PG', style: const TextStyle(fontWeight: FontWeight.bold)),
                  children: [
                    for (var i = 0; i < doc.pg.length && i < 60; i++)
                      ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        title: Text('${i + 1}. ${doc.pg[i].soal}', style: const TextStyle(fontSize: 12)),
                        subtitle: Text(
                            '${doc.pg[i].opsi.map((o) => o.length > 40 ? '${o.substring(0, 40)}…' : o).join(' | ')}'
                            '${doc.pg[i].kunci != null ? '  → kunci ${doc.pg[i].kunci}' : ''}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10)),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.secondary),
                onPressed: _importing || doc.pg.isEmpty && doc.jodoh.isEmpty && doc.essay.isEmpty
                    ? null
                    : _import,
                icon: _importing
                    ? const SizedBox(height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text('IMPORT ${doc.pg.length + doc.jodoh.length + doc.essay.length} SOAL '
                    '(+ mapel & ujian draft)'),
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}