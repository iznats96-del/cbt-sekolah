import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../../services/sheet_parser.dart';

/// Layar impor massal siswa / mapel dari xls, xlsx, csv.
class ImportScreen extends StatefulWidget {
  final bool isSiswa;
  const ImportScreen({super.key, required this.isSiswa});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  List<SiswaTable> _tables = [];
  List<Map<String, String>> _mapelRows = [];
  final Map<String, Uint8List> _imgStore = {};
  bool _parsing = false;
  bool _importing = false;
  String? _fileName;
  String? _error;
  final _pwCtrl = TextEditingController();

  @override
  void dispose() {
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xls', 'xlsx', 'csv', 'docx', 'dotx'],
    );
    if (files.isEmpty) return;
    final f = files.first;
    Uint8List bytes;
    try {
      bytes = await f.readAsBytes();
    } catch (_) {
      setState(() => _error = 'Gagal membaca file.');
      return;
    }
    setState(() {
      _parsing = true;
      _error = null;
      _fileName = f.name;
      _tables = [];
      _mapelRows = [];
    });
    try {
      final sheets = SheetParser.parse(bytes);
      if (widget.isSiswa) {
        final tables = SiswaImportMapper.fromSheets(sheets)
            .where((t) => t.rows.isNotEmpty)
            .toList();
        if (tables.every((t) => t.rows.isEmpty)) {
          setState(() {
            _error = 'Tidak ditemukan kolom NAMA SISWA. Gunakan format export absensi / template (kolom: NIS, NAMA LENGKAP).';
            _parsing = false;
          });
          return;
        }
        setState(() {
          _tables = tables;
          _parsing = false;
        });
      } else {
        _imgStore.clear();
        final per = <Map<String, String>>[];
        for (final s in sheets) {
          for (final e in s.images.entries) {
            _imgStore[e.key] = e.value;
          }
          for (final m in MapelMapper.fromRows(s.rows)) {
            if (m['nama'] == null) continue;
            if (!per.any((e) => e['nama'] == m['nama'])) {
              per.add(m);
            }
          }
        }
        final rows = per;
        if (rows.isEmpty) {
          setState(() {
            _error = 'Tidak ditemukan data mata pelajaran. Format diterima: tabel excel (MATA PELAJARAN|KODE|JURUSAN|KKM), csv, atau docx (satu mapel per baris, gambar ikut terbaca sebagai logo).';
            _parsing = false;
          });
          return;
        }
        setState(() {
          _mapelRows = rows;
          _parsing = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Gagal parsing: $e';
        _parsing = false;
      });
    }
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    try {
      dynamic res;
      if (widget.isSiswa) {
        final rows = <Map<String, dynamic>>[];
        for (final t in _tables) {
          for (final r in t.rows) {
            rows.add({
              'nis': r['nis'] ?? '',
              'nisn': r['nisn'] ?? '',
              'nama': r['nama'] ?? '',
              'jk': r['jk'] ?? '',
              'kelas': (r['kelas'] != null && r['kelas']!.isNotEmpty) ? r['kelas'] : t.kelas,
              'tingkat': '${t.tingkat ?? ''}',
            });
          }
        }
        final pw = _pwCtrl.text.trim();
        res = await Api.client.rpc('admin_import_siswa', params: {
          'p_rows': rows,
          'p_password': pw.isEmpty ? null : pw,
        });
      } else {
        final payload = <Map<String, dynamic>>[];
        for (final m in _mapelRows) {
          final row = <String, dynamic>{
            'nama': m['nama'],
            'kode': m['kode'] ?? '',
            'jurusan': m['jurusan'] ?? '',
            'kkm': m['kkm'] ?? '',
          };
          final img = m['img'];
          if (img != null && img.isNotEmpty && _imgStore.containsKey(img)) {
            try {
              final ext = img.split('.').last.toLowerCase();
              final path = 'mapel/${DateTime.now().millisecondsSinceEpoch}_${(m['nama'] ?? 'mapel').toString().hashCode}.$ext';
              await Api.client.storage.from('soal').uploadBinary(
                path,
                _imgStore[img]!,
                fileOptions: FileOptions(
                    contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
                    upsert: true),
              );
              row['logo_url'] = Api.client.storage.from('soal').getPublicUrl(path);
            } catch (_) {/* logo opsional */}
          }
          payload.add(row);
        }
        res = await Api.client
            .rpc('admin_import_mapel', params: {'p_rows': payload});
      }
      final m = res is Map ? Map<String, dynamic>.from(res as Map) : <String, dynamic>{};
      final created = m['created'] ?? 0;
      final updated = m['updated'] ?? 0;
      final skipped = m['skipped'] ?? 0;
      final imported = m['imported'] ?? 0;
      // nomor peserta langsung terbit saat import (TKJ-1-2627-01 + username + password)
      Map<String, dynamic> nm = {};
      if (widget.isSiswa) {
        try {
          final nr = await Api.client.rpc('admin_isi_nomor_kosong');
          if (nr is Map) nm = Map<String, dynamic>.from(nr);
        } catch (_) {/* nomor tetap aman: diisi saat terbit ujian */}
      }
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Hasil Impor'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isSiswa) ...[
                Text('Akun baru dibuat: $created'),
                Text('Diperbarui: $updated'),
                if (skipped is int && skipped > 0)
                  Text('Dilewati: $skipped', style: const TextStyle(color: Colors.orange)),
                const SizedBox(height: 8),
                if ((nm['diisi'] ?? 0) is int && (nm['diisi'] as int) > 0)
                  Text('Nomor peserta terbit: ${nm['diisi']} (cth ${nm['contoh'] ?? ''})',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                if (pw_is_default(_pwCtrl))
                  const Text('Password awal siswa = NIS mereka.',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                const Text('Username = NIS • password + nomor lihat di Daftar Akun.',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ] else
                Text('$imported mata pelajaran tersimpan/diperbarui.'),
            ],
          ),
          actions: [
            FilledButton(onPressed: () {
              Navigator.pop(c);
              _reset();
            }, child: const Text('Selesai')),
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

  bool pw_is_default(TextEditingController c) => c.text.trim().isEmpty;

  void _reset() {
    setState(() {
      _tables = [];
      _mapelRows = [];
      _fileName = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: Text(widget.isSiswa ? 'Import Siswa' : 'Import Mata Pelajaran')),
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
                  Text(
                    widget.isSiswa
                        ? 'Format didukung: export absensi/sekolah (.xls XML), Excel 2007+ (.xlsx), CSV.\n'
                            'Kolom dikenali otomatis: NIS/NISN, NAMA SISWA, L/P, KELAS.\n'
                            'Tanpa NIS? Otomatis dibuat + password awal = NIS.'
                        : 'Format didukung: Excel 2007+ (.xlsx), CSV, dan DOCX — satu mapel per baris tabel/paragraf; gambar (PNG) pada baris ikut ter-upload jadi ikon mapel.\n'
                            'Kolom Excel/CSV: MATA PELAJARAN | KODE | JURUSAN | KKM.',
                    style: const TextStyle(fontSize: 12, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _parsing ? null : _pickFile,
                    icon: _parsing
                        ? const SizedBox(
                            height: 16, width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.upload_file),
                    label: const Text('Pilih File'),
                  ),
                  if (_fileName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('File: $_fileName', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              color: AppTheme.danger.withOpacity(0.05),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.danger),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 12))),
                  ],
                ),
              ),
            ),
          ],
          if (widget.isSiswa && _tables.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Password awal (kosongkan = pakai NIS):', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _pwCtrl,
              decoration: const InputDecoration(hintText: 'mis: sekolah123'),
            ),
            const SizedBox(height: 16),
            for (final t in _tables)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ExpansionTile(
                  title: Text('${t.kelas.isEmpty ? '(tanpa kelas)' : t.kelas} · ${t.rows.length} siswa'),
                  subtitle: Text(
                    t.rows.take(5).map((r) => '${(r['nis']?.isNotEmpty ?? false) ? r['nis'] : '(auto)'}  ${r['nama']}').join('\n'),
                    maxLines: 5,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: DataTable(
                        headingRowHeight: 32,
                        dataRowMinHeight: 32,
                        columns: const [
                          DataColumn(label: Text('NIS')),
                          DataColumn(label: Text('Nama')),
                          DataColumn(label: Text('Jk')),
                          DataColumn(label: Text('Kelas')),
                        ],
                        rows: [
                          for (final r in t.rows)
                            DataRow(cells: [
                              DataCell(Text(r['nis'] ?? '')),
                              DataCell(Text(r['nama'] ?? '')),
                              DataCell(Text(r['jk'] ?? '')),
                              DataCell(Text((r['kelas']?.isNotEmpty ?? false) ? r['kelas']! : t.kelas)),
                            ]),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (!widget.isSiswa && _mapelRows.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: DataTable(
                  headingRowHeight: 32,
                  dataRowMinHeight: 32,
                  columns: const [
                    DataColumn(label: Text('Mata Pelajaran')),
                    DataColumn(label: Text('Kode')),
                    DataColumn(label: Text('Jurusan')),
                    DataColumn(label: Text('KKM')),
                  ],
                  rows: [
                    for (final m in _mapelRows)
                      DataRow(cells: [
                        DataCell(Text((m['nama'] ?? '') +
                            ((m['img']?.isNotEmpty ?? false) ? '  (ada gambar)' : ''))),
                        DataCell(Text(m['kode'] ?? '')),
                        DataCell(Text(m['jurusan'] ?? '')),
                        DataCell(Text(m['kkm'] ?? '')),
                      ]),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (_tables.isNotEmpty || _mapelRows.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.secondary),
                onPressed: _importing ? null : _import,
                child: _importing
                    ? const SizedBox(
                        height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(widget.isSiswa
                        ? 'Impor ${_tables.expand((t) => t.rows).length} Siswa'
                        : 'Impor ${_mapelRows.length} Mata Pelajaran'),
              ),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}