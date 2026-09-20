import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
                'id,nomor_peserta,status,siswa(nama,nis,kelas(nama,jurusan(singkatan,nama)))')
            .eq('ujian_id', _ujianId)
            .order('nomor_peserta', ascending: true),
        Api.client.from('sekolah').select('nama').limit(1),
      ]);
      final p = List<Map<String, dynamic>>.from(rows[0] as List);
      final s = rows[1] as List;
      if (!mounted) return;
      setState(() {
        _peserta = p;
        if (s.isNotEmpty && '${s.first['nama']}'.isNotEmpty) {
          _sekolah = '${s.first['nama']}';
        }
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

  // ================= PDF: KARTU PESERTA =================
  Future<void> _printKartu() async {
    final doc = pw.Document();
    final list = _shown;
    const perPage = 8; // 2 kolom x 4 baris
    for (var i = 0; i < list.length; i += perPage) {
      final chunk = list.sublist(
          i, i + perPage > list.length ? list.length : i + perPage);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(16),
          build: (_) => pw.Column(
            children: [
              pw.Text('KARTU PESERTA UJIAN — ${_ujianNama.toUpperCase()}',
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text(_sekolah,
                  style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 10),
              pw.GridView(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.55,
                children: [
                  for (final p in chunk)
                    pw.Container(
                      padding: const pw.EdgeInsets.all(10),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                            color: PdfColors.blue900, width: 1.2),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(_sekolah.toUpperCase(),
                                  style: pw.TextStyle(
                                      fontSize: 7,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.blue900)),
                              pw.Text('PESERTA',
                                  style: pw.TextStyle(
                                      fontSize: 7,
                                      fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                          pw.Divider(color: PdfColors.blue900, height: 8),
                          pw.Center(
                            child: pw.Text(
                                '${p['nomor_peserta'] ?? '-'}',
                                style: pw.TextStyle(
                                    fontSize: 18,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Center(
                              child: pw.Text(_nama(p),
                                  style: pw.TextStyle(
                                      fontSize: 10,
                                      fontWeight: pw.FontWeight.bold))),
                          pw.Center(
                              child: pw.Text(
                                  'NIS ${_nis(p)} • ${_kelas(p)}',
                                  style: const pw.TextStyle(fontSize: 8))),
                          pw.Spacer(),
                          pw.Text(_ujianNama,
                              style: const pw.TextStyle(
                                  fontSize: 7, color: PdfColors.grey700)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
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
                                          .withOpacity(0.12),
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
                                            .withOpacity(0.1),
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
