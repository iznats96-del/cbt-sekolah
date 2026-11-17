import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../../services/ujian_docx_parser.dart';
import '../../widgets/dashboard_header.dart';

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
  TextEditingController _kelasCtrl = TextEditingController();
  List<Map<String,dynamic>> _kelOptions = [];
  String? _kelSelectedId;
  bool _kelLoading = false;
  final _judulCtrl = TextEditingController();
  final _waktuCtrl = TextEditingController(text: '60');
  String? _fileName;

  Future<void> _loadKelas() async {
    setState(() => _kelLoading = true);
    try {
      final rows = await Api.client
          .from('kelas')
          .select('id,nama,jurusan(singkatan)')
          .order('nama');
      setState(() {
        _kelOptions = List<Map<String, dynamic>>.from(rows);
        _kelLoading = false;
      });
    } catch (_) {
      setState(() => _kelLoading = false);
    }
  }

  /// dokumen nulis 'X AKUNTA' / 'XI TKJ' → rombel asli X AKA 1 / XI TKJ 1(?)
  String? _guessKelas(String docKelas) {
    final up = docKelas.toUpperCase().trim();
    String tingkat = '';
    for (final t in ['XII', 'XI', 'X']) {
      if (up.startsWith(t)) { tingkat = t; break; }
    }
    if (tingkat.isEmpty) return null;
    final rest = up
        .substring(tingkat.length)
        .replaceAll(RegExp(r'[^A-Z0-9]'), '')
        .replaceAll(RegExp(r'^(SEBELAS|DUA BELAS|SEPULUH)*'), '');
    final cand = _kelOptions
        .where((k) => '${k['nama']}'.toUpperCase().startsWith(tingkat))
        .toList();
    List<Map<String, dynamic>> pool;
    if (tingkat == 'XI') {
      pool = cand.where((k) => RegExp(r'^XI[^I]').hasMatch('${k['nama']}'.toUpperCase().trim())).toList();
    } else if (tingkat == 'XII') {
      pool = cand.where((k) => '${k['nama']}'.toUpperCase().trim().startsWith('XII')).toList();
    } else {
      pool = cand.where((k) => RegExp(r'^X[^I]').hasMatch('${k['nama']}'.toUpperCase().trim())).toList();
    }
    if (pool.isEmpty) return null;
    if (pool.length == 1 || rest.isEmpty) return '${pool.first['id']}';
    for (final k in pool) {
      final j = k['jurusan'];
      final kode = (j is Map ? '${j['singkatan'] ?? ''}' : '').toUpperCase();
      if (kode.isNotEmpty && rest.startsWith(kode)) return '${k['id']}';
      final nm = '${k['nama']}'.toUpperCase();
      if (kode.isNotEmpty && nm.contains(kode) && rest.startsWith(kode)) return '${k['id']}';
    }
    return null;
  }

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx', 'dotx'],
    );
    if (files.isEmpty) return;
    final f = files.first;
    if (_kelOptions.isEmpty) await _loadKelas();
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
        _kelSelectedId = _guessKelas(doc.kelas);
        _judulCtrl.text = doc.judul;
        _waktuCtrl.text = '${doc.waktuMenit ?? 60}';
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
      await Api.routerStorageUpload(
        'soal',
        p,
        bytes,
        contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
        upsert: true,
      );
      return Api.routerStorageGetPublicUrl('soal', p);
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
      for (final e in doc.essay) {
        items.add({
          'jenis': 'essay',
          'soal': e.soal,
          'opsi': null,
          'kunci': null,
          'bobot': '1',
        });
      }
      for (final j in doc.jodoh) {
        // 1 grup jodoh = 1 soal di bank. kunci.map diisi dari pasangan
        // yang benar bila dokumen menyediakannya; kalau tidak, guru isi manual.
        final kiri = j.kiri;
        final kanan = j.kanan;
        final map = <String, String>{};
        // Coba parse kunci dari teks kayak "1-A, 2-B, 3-C"
        if (j.kunciText != null) {
          for (final m in RegExp(r'(\d+)\s*[-.:=]\s*([A-J])', caseSensitive: false).allMatches(j.kunciText!)) {
            final a = (int.tryParse(m.group(1)!) ?? 0) - 1;
            final b = m.group(2)!.toUpperCase().codeUnitAt(0) - 65;
            if (a >= 0 && a < kiri.length && b >= 0 && b < kanan.length) {
              map['$a'] = '$b';
            }
          }
        }
        items.add({
          'jenis': 'jodoh',
          'soal': 'Jodohkan pasangan berikut:',
          'opsi': {'kiri': kiri, 'kanan': kanan},
          'kunci': map.isEmpty ? null : {'map': map},
          'bobot': '1',
        });
      }

      final payload = <String, dynamic>{
        'mapel': _mapelCtrl.text.trim(),
        'jurusan': doc.jurusan ?? '',
        'kelas': _kelasCtrl.text.trim(),
        'kelas_id': _kelSelectedId ?? '',
        'judul': _judulCtrl.text.trim(),
        'waktu': _waktuCtrl.text.trim(),
        'token': '',
        'jenis_ujian': 'Penilaian Sumatif',
        'guru': doc.guru,
        'items': items,
      };
      final res = await Api.client.rpc('admin_import_ujian_docx', params: {
        'p_payload': payload,
      });
      final map = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Ujian Berhasil Diimpor '),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mapel: ${map['mapel']}'),
              Text('Kelas: ${map['kelas']}'),
              Text('Soal masuk: ${map['soal_count']}'),
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
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: const DashboardHeader(title: 'IMPORT UJIAN DARI DOCX', showBack: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Format: naskah ujian sekolah (.docx) yang berisi kop, "Mata Pelajaran:", '
                    '"Kelas/Kompetensi keahlian:", "Waktu: 60 menit", sesi "PILIHAN GANDA" '
                    '(opsi a. A. ... s.d. e. E.), tabel "MENJODOHKAN" (Soal | Pilihan Jawaban | Jawaban), '
                    '"Essay Uraian", dan "KUNCI JAWABAN" (1. B, dst).',
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
              color: AppTheme.danger.withValues(alpha: 0.06),
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
                color: Colors.orange.withValues(alpha: 0.08),
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
                    DropdownButtonFormField<String?>(
                      value: _kelSelectedId,
                      borderRadius: BorderRadius.circular(12),
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Kelas (rombel wajib sudah ada) *',
                          helperText: 'kalau rombel baru, buat dulu di Data Master → Kelas / Rombel'),
                      items: [
                        if (_kelSelectedId == null)
                          const DropdownMenuItem(
                              value: null, child: Text('— pilih / belum ketemu —')),
                        ..._kelOptions.map((k) {
                          final j = k['jurusan'];
                          return DropdownMenuItem(
                              value: '${k['id']}',
                              child: Text(
                                  '${k['nama']}${j is Map && j['singkatan'] != null ? '  •  ${j['singkatan']}' : ''}'));
                        }),
                      ],
                      onChanged: (v) => setState(() => _kelSelectedId = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _judulCtrl, decoration: const InputDecoration(labelText: 'Judul Ujian')),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _waktuCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Alokasi (menit)'),
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
            if (doc.jodoh.isNotEmpty)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  title: Text('Pratinjau ${doc.jodoh.length} grup Jodoh ('
                      '${doc.jodoh.fold<int>(0, (s, j) => s + j.kiri.length)} item)',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  children: [
                    for (var i = 0; i < doc.jodoh.length; i++)
                      ListTile(
                        dense: true,
                        title: Text('Grup ${i + 1}', style: const TextStyle(fontSize: 12)),
                        subtitle: Text(
                          'Kiri: ${doc.jodoh[i].kiri.join(' | ')}\n'
                          'Kanan: ${doc.jodoh[i].kanan.join(' | ')}',
                          style: const TextStyle(fontSize: 10), maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.secondary),
                onPressed: _importing || (doc.pg.isEmpty && doc.essay.isEmpty && doc.jodoh.isEmpty)
                    ? null
                    : _import,
                icon: _importing
                    ? const SizedBox(height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload_outlined),
                label: Text('IMPORT ${doc.pg.length + doc.essay.length + doc.jodoh.length} SOAL '
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