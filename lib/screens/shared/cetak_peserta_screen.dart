import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';

/// Cetak nomor peserta format baru KODE-S-YYZZ-NN (mis TKJ-1-2627-01).
/// Dua keluaran PDF: Kartu Peserta (per siswa) + Daftar Nominatif (tabel).
class CetakPesertaScreen extends StatefulWidget {
  final Map<String, dynamic> ujian;
  const CetakPesertaScreen({super.key, required this.ujian});

  @override
  State<CetakPesertaScreen> createState() => _CetakPesertaScreenState();
}

class _CetakPesertaScreenState extends State<CetakPesertaScreen> {
  List<Map<String, dynamic>> _peserta = [];
  bool _loading = true;
  String? _error;
  String _q = '';
  String _sekolah = 'SMK YP 79 Majalaya';
  String _kepala = '';
  String _nip = '';
  Map<String, String> _pwByProfile = {};

  String get _ujianId => '${widget.ujian['id']}';
  String get _ujianNama => '${widget.ujian['nama'] ?? 'Ujian'}';

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
      final rows = await Future.wait([
        Api.client
            .from('peserta_ujian')
            .select(
                'id,nomor_peserta,status,foto_url,siswa(profile_id,nama,nis,foto_url,kelas(nama,jurusan(singkatan,nama)))')
            .eq('ujian_id', _ujianId)
            .order('nomor_peserta', ascending: true),
        Api.client
            .from('sekolah')
            .select('nama,kepala_sekolah,nip_kepala')
            .limit(1),
      ]);
      final p = List<Map<String, dynamic>>.from(rows[0] as List);
      final s = rows[1] as List;
      final ids = <String>[];
      for (final x in p) {
        final sw = x['siswa'];
        if (sw is Map && '${sw['profile_id']}'.isNotEmpty) {
          ids.add('${sw['profile_id']}');
        }
      }
      Map<String, String> pwMap = {};
      if (ids.isNotEmpty) {
        try {
          final pr = await Api.client
              .from('profiles')
              .select('id,pw_default')
              .filter('id', 'in', ids);
          pwMap = {
            for (final r in (pr as List))
              '${r['id']}': '${r['pw_default'] ?? ''}'
          };
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _peserta = p;
        if (s.isNotEmpty) {
          final sm = Map<String, dynamic>.from(s.first as Map);
          if ('${sm['nama']}'.isNotEmpty) _sekolah = '${sm['nama']}';
          _kepala = '${sm['kepala_sekolah'] ?? ''}';
          _nip = '${sm['nip_kepala'] ?? ''}';
        }
        _pwByProfile = pwMap;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat peserta: $e';
        _loading = false;
      });
    }
  }

  Future<void> _terbitkan() async {
    try {
      final res = await Api.client
          .rpc('terbitkan_nomor_peserta', params: {'p_ujian': _ujianId});
      final m = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Nomor terbit ${m['total'] ?? 0} • format ${m['format'] ?? ''} • cth ${m['contoh'] ?? ''}'),
        backgroundColor: AppTheme.secondary,
        duration: const Duration(seconds: 5),
      ));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal terbitkan: $e'),
          backgroundColor: AppTheme.danger));
    }
  }

  List<Map<String, dynamic>> get _shown {
    if (_q.trim().isEmpty) return _peserta;
    final q = _q.toLowerCase();
    return _peserta.where((p) {
      final s = p['siswa'] is Map ? p['siswa'] as Map : const {};
      return '${s['nama'] ?? ''} ${s['nis'] ?? ''} ${p['nomor_peserta'] ?? ''}'
          .toLowerCase()
          .contains(q);
    }).toList();
  }

  String _nama(Map<String, dynamic> p) {
    final s = p['siswa'];
    return s is Map ? '${s['nama'] ?? '?'}' : '?';
  }

  String _nis(Map<String, dynamic> p) {
    final s = p['siswa'];
    return s is Map ? '${s['nis'] ?? '-'}' : '-';
  }

  String _kelas(Map<String, dynamic> p) {
    final s = p['siswa'];
    final k = s is Map ? s['kelas'] : null;
    if (k is Map) {
      final j = k['jurusan'];
      final js = j is Map && j['singkatan'] != null ? ' • ${j['singkatan']}' : '';
      return '${k['nama'] ?? ''}$js';
    }
    return '-';
  }

  // ================= PDF: DAFTAR NOMINATIF =================
  Future<void> _printDaftar() async {
    final doc = pw.Document();
    final list = _shown;
    const perPage = 28;
    for (var i = 0; i < list.length; i += perPage) {
      final chunk = list.sublist(
          i, i + perPage > list.length ? list.length : i + perPage);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(children: [
                  pw.Text(_sekolah.toUpperCase(),
                      style: pw.TextStyle(
                          fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.Text('DAFTAR NOMINATIF PESERTA UJIAN',
                      style: pw.TextStyle(
                          fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text(_ujianNama,
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 8),
                ]),
              ),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(
                    fontSize: 8, fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.grey300),
                headers: const [
                  'No',
                  'Nomor Peserta',
                  'Nama',
                  'NIS',
                  'Kelas',
                  'TTD'
                ],
                data: [
                  for (var j = 0; j < chunk.length; j++)
                    [
                      '${i + j + 1}',
                      '${chunk[j]['nomor_peserta'] ?? '-'}',
                      _nama(chunk[j]),
                      _nis(chunk[j]),
                      _kelas(chunk[j]),
                      '',
                    ],
                ],
                columnWidths: {
                  0: const pw.FixedColumnWidth(24),
                  1: const pw.FixedColumnWidth(92),
                  5: const pw.FixedColumnWidth(60),
                },
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Column(children: [
                    pw.Text('Majalaya, _______________',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.SizedBox(height: 36),
                    pw.Text('( ................................... )',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('Panitia / Pengawas',
                        style: const pw.TextStyle(fontSize: 8)),
                  ]),
                ],
              ),
              pw.Spacer(),
              pw.Text(
                  'Format: KODE-S-YYZZ-NN • S=1 Ganjil/2 Genap • NN=urut abjad per jurusan • Hal ${(i ~/ perPage) + 1}',
                  style: const pw.TextStyle(
                      fontSize: 7, color: PdfColors.grey600)),
            ],
          ),
        ),
      );
    }
    await Printing.layoutPdf(
        onLayout: (_) async => doc.save(),
        name: 'nominatif-${_ujianNama.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')}');
  }

  Future<Uint8List?> _assetBytes(String path) async {
    try {
      final d = await rootBundle.load(path);
      return d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _urlBytes(String? url) async {
    if (url == null || url.isEmpty || url == 'null') return null;
    try {
      final r = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      return r.statusCode == 200 ? r.bodyBytes : null;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _qrBytes(String data) async {
    try {
      final b = await QrPainter(data: data, version: QrVersions.auto)
          .toImageData(120);
      return b?.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes);
    } catch (_) {
      return null;
    }
  }

  String _tahunAjaran() {
    DateTime d = DateTime.now();
    final raw = widget.ujian['tanggal'];
    if (raw != null && '$raw'.isNotEmpty) {
      final p = DateTime.tryParse('$raw');
      if (p != null) d = p;
    }
    return d.month >= 7 ? '${d.year}/${d.year + 1}' : '${d.year - 1}/${d.year}';
  }

  pw.Widget _field(String label, String value, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
                width: 70,
                child: pw.Text('$label :',
                    style: const pw.TextStyle(
                        fontSize: 6.5, color: PdfColors.grey700))),
            pw.Expanded(
                child: pw.Text(
                    value.isEmpty || value == 'null' ? '-' : value,
                    style: pw.TextStyle(
                        fontSize: 6.8,
                        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
          ],
        ),
      );

  // ================= PDF: KARTU PESERTA =================
  Future<void> _printKartu() async {
    final doc = pw.Document();
    final logoBytes = await _assetBytes('assets/images/logo_yp.png');
    final logo = logoBytes == null ? null : pw.MemoryImage(logoBytes);
    final list = _shown;
    final tahun = _tahunAjaran();
    const perPage = 8;
    for (var i = 0; i < list.length; i += perPage) {
      final chunk = list.sublist(
          i, i + perPage > list.length ? list.length : i + perPage);
      final cards = <pw.Widget>[];
      for (final p in chunk) {
        final sw = p['siswa'] is Map
            ? Map<String, dynamic>.from(p['siswa'] as Map)
            : <String, dynamic>{};
        final nis = '${sw['nis'] ?? '-'}';
        final profId = '${sw['profile_id'] ?? ''}';
        final pass = _pwByProfile[profId] ?? '';
        final foto = await _urlBytes('${sw['foto_url'] ?? p['foto_url'] ?? ''}');
        final qr = await _qrBytes('${p['nomor_peserta'] ?? nis}');
        cards.add(pw.Container(
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey800, width: 0.8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logo != null)
                    pw.Image(logo, width: 26, height: 26)
                  else
                    pw.SizedBox(width: 26, height: 26),
                  pw.SizedBox(width: 4),
                  pw.Expanded(
                    child: pw.Column(
                      children: [
                        pw.Text('KARTU PESERTA CBT UM',
                            style: pw.TextStyle(
                                fontSize: 8.5,
                                fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                        pw.Text(_sekolah.toUpperCase(),
                            style: pw.TextStyle(
                                fontSize: 7, fontWeight: pw.FontWeight.bold),
                            textAlign: pw.TextAlign.center),
                        pw.Text('TAHUN PELAJARAN $tahun',
                            style: const pw.TextStyle(fontSize: 6.2),
                            textAlign: pw.TextAlign.center),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 4),
                  if (logo != null)
                    pw.Image(logo, width: 26, height: 26)
                  else
                    pw.SizedBox(width: 26, height: 26),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 50,
                    height: 60,
                    decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400)),
                    child: foto == null
                        ? pw.Center(
                            child: pw.Text('FOTO',
                                style: pw.TextStyle(
                                    fontSize: 6, color: PdfColors.grey)))
                        : pw.Image(pw.MemoryImage(foto),
                            fit: pw.BoxFit.cover, width: 50, height: 60),
                  ),
                  pw.SizedBox(width: 7),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _field('No Peserta', '${p['nomor_peserta'] ?? '-'}'),
                        _field('Nama', _nama(p), bold: true),
                        _field('Kelas / Sesi', _kelas(p)),
                        _field('Username', nis),
                        _field('Password', pass),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 6, bottom: 2),
                    child: qr != null
                        ? pw.Image(pw.MemoryImage(qr), width: 42, height: 42)
                        : pw.SizedBox(width: 42, height: 42),
                  ),
                  pw.Spacer(),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Kepala Sekolah',
                          style: const pw.TextStyle(fontSize: 6.5)),
                      pw.SizedBox(height: 13),
                      pw.Text(
                          _kepala.isEmpty ? '......................' : _kepala,
                          style: pw.TextStyle(
                              fontSize: 6.3, fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                          _nip.isEmpty ? 'NIP. ....................' : 'NIP. $_nip',
                          style: const pw.TextStyle(fontSize: 5.3)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ));
      }
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(14),
        build: (_) => pw.GridView(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.42,
          children: cards,
        ),
      ));
    }
    await Printing.layoutPdf(
        onLayout: (_) async => doc.save(),
        name: 'kartu-${_ujianNama.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text('Nomor & Cetak: $_ujianNama',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
              tooltip: 'Terbitkan nomor format baru',
              icon: const Icon(Icons.format_list_numbered),
              onPressed: _terbitkan),
          IconButton(
              tooltip: 'Cetak daftar nominatif (PDF)',
              icon: const Icon(Icons.print_outlined),
              onPressed: _peserta.isEmpty ? null : _printDaftar),
          IconButton(
              tooltip: 'Cetak kartu peserta (PDF)',
              icon: const Icon(Icons.badge_outlined),
              onPressed: _peserta.isEmpty ? null : _printKartu),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: _load,
                            child: const Text('Muat Ulang')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF3FB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 18, color: AppTheme.primary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Format: TKJ-1-2627-01 = Jurusan-Semester(1 Ganjil/2 Genap)-Tahun(2627)-Urut abjad per jurusan (01..)',
                              style: TextStyle(fontSize: 11.5, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              onChanged: (v) => setState(() => _q = v),
                              decoration: const InputDecoration(
                                hintText: 'cari nama / NIS / nomor...',
                                isDense: true,
                                prefixIcon:
                                    Icon(Icons.search, size: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.secondary),
                            onPressed: _terbitkan,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Terbitkan'),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _peserta.isEmpty
                                  ? null
                                  : _printDaftar,
                              icon: const Icon(
                                  Icons.table_view_outlined,
                                  size: 18),
                              label: const Text('Daftar (PDF)',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed:
                                  _peserta.isEmpty ? null : _printKartu,
                              icon: const Icon(Icons.badge_outlined,
                                  size: 18),
                              label: const Text('Kartu (PDF)',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _shown.isEmpty
                          ? const Center(
                              child: Text(
                                  'Belum ada peserta.\nTekan Terbitkan untuk buat nomor.',
                                  textAlign: TextAlign.center,
                                  style:
                                      TextStyle(color: Colors.grey)))
                          : ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: _shown.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (c, i) {
                                final p = _shown[i];
                                return Card(
                                  margin: EdgeInsets.zero,
                                  child: ListTile(
                                    dense: true,
                                    leading: CircleAvatar(
                                      radius: 15,
                                      backgroundColor: AppTheme.primary
                                          .withValues(alpha: 0.12),
                                      child: Text('${i + 1}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.primary,
                                              fontWeight:
                                                  FontWeight.bold)),
                                    ),
                                    title: Text(_nama(p),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13)),
                                    subtitle: Text(
                                        'NIS ${_nis(p)} • ${_kelas(p)}',
                                        style: const TextStyle(
                                            fontSize: 11)),
                                    trailing: Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 5),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                          '${p['nomor_peserta'] ?? '—'}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primary)),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
