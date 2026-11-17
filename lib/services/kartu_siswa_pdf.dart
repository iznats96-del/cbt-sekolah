import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';

class KartuSiswaData {
  final String noPeserta, nama, kelas, username, password, fotoUrl, qrData;
  const KartuSiswaData({
    required this.noPeserta,
    required this.nama,
    required this.kelas,
    required this.username,
    required this.password,
    required this.fotoUrl,
    required this.qrData,
  });
}

/// Kartu peserta CBT per SISWA (bukan kartu ujian).
/// Sumber data: tabel siswa + profiles (pw_default) + sekolah.
/// Layout referensi: 2 logo, judul 3 baris, foto kiri, field, QR, TTD, 8/A4.
class KartuSiswaPdf {
  KartuSiswaPdf._();

  static String tahunAjaran([DateTime? t]) {
    final d = t ?? DateTime.now();
    return d.month >= 7 ? '${d.year}/${d.year + 1}' : '${d.year - 1}/${d.year}';
  }

  static Future<Uint8List> build({
    required List<KartuSiswaData> cards,
    required String sekolah,
    required String kepala,
    required String nip,
    String? tahun,
  }) async {
    final doc = pw.Document();
    final lb = await _assetBytes();
    final logo = lb == null ? null : pw.MemoryImage(lb);
    final thn = tahun ?? tahunAjaran();
    const perPage = 8;

    for (var i = 0; i < cards.length; i += perPage) {
      final chunk = cards.skip(i).take(perPage).toList();
      final widgets = <pw.Widget>[];
      for (final c in chunk) {
        final foto = await _urlBytes(c.fotoUrl);
        final qr = await _qrBytes(c.qrData);
        widgets.add(_card(c, logo, foto, qr, sekolah, kepala, nip, thn));
      }
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(14),
        build: (_) => pw.GridView(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.42,
          children: widgets,
        ),
      ));
    }
    return doc.save();
  }

  static pw.Widget _card(
    KartuSiswaData c,
    pw.ImageProvider? logo,
    Uint8List? foto,
    Uint8List? qr,
    String sekolah,
    String kepala,
    String nip,
    String tahun,
  ) {
    return pw.Container(
      padding: pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey800, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            if (logo != null)
              pw.Image(logo, width: 26, height: 26)
            else
              pw.SizedBox(width: 26, height: 26),
            pw.SizedBox(width: 4),
            pw.Expanded(
              child: pw.Column(children: [
                pw.Text('KARTU PESERTA CBT UM',
                    style: pw.TextStyle(
                        fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center),
                pw.Text(sekolah.toUpperCase(),
                    style: pw.TextStyle(
                        fontSize: 7, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center),
                pw.Text('TAHUN PELAJARAN $tahun',
                    style: pw.TextStyle(fontSize: 6.2),
                    textAlign: pw.TextAlign.center),
              ]),
            ),
            pw.SizedBox(width: 4),
            if (logo != null)
              pw.Image(logo, width: 26, height: 26)
            else
              pw.SizedBox(width: 26, height: 26),
          ]),
          pw.SizedBox(height: 4),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Container(
              width: 50,
              height: 60,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
              ),
              child: foto == null
                  ? pw.Center(
                      child: pw.Text('FOTO',
                          style: pw.TextStyle(fontSize: 6, color: PdfColors.grey)))
                  : pw.Image(pw.MemoryImage(foto),
                      fit: pw.BoxFit.cover, width: 50, height: 60),
            ),
            pw.SizedBox(width: 7),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _field('No Peserta', c.noPeserta.isEmpty ? '-' : c.noPeserta),
                  _field('Nama', c.nama.isEmpty ? '-' : c.nama, bold: true),
                  _field('Kelas / Sesi', c.kelas.isEmpty ? '-' : c.kelas),
                  _field('Username', c.username.isEmpty ? '-' : c.username),
                  _field('Password', c.password.isEmpty ? '-' : c.password),
                ],
              ),
            ),
          ]),
          pw.SizedBox(height: 4),
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            if (qr != null)
              pw.Image(pw.MemoryImage(qr), width: 40, height: 40)
            else
              pw.SizedBox(width: 40, height: 40),
            pw.Spacer(),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.Text('Kepala Sekolah',
                  style: pw.TextStyle(fontSize: 6.5)),
              pw.SizedBox(height: 13),
              pw.Text(kepala.isEmpty ? '......................' : kepala,
                  style: pw.TextStyle(
                      fontSize: 6.3, fontWeight: pw.FontWeight.bold)),
              pw.Text(nip.isEmpty ? 'NIP. ....................' : 'NIP. $nip',
                  style: pw.TextStyle(fontSize: 5.3)),
            ]),
          ]),
        ],
      ),
    );
  }

  static pw.Widget _field(String label, String value, {bool bold = false}) =>
      pw.Padding(
        padding: pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.SizedBox(
              width: 70,
              child: pw.Text('$label :',
                  style: pw.TextStyle(
                      fontSize: 6.5, color: PdfColors.grey700))),
          pw.Expanded(
              child: pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 6.8,
                      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal))),
        ]),
      );

  static Future<Uint8List?> _assetBytes() async {
    try {
      final d = await rootBundle.load('assets/images/logo_yp.png');
      return d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> _urlBytes(String url) async {
    if (url.isEmpty || url == 'null') return null;
    try {
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      return r.statusCode == 200 ? r.bodyBytes : null;
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> _qrBytes(String data) async {
    try {
      final b =
          await QrPainter(data: data, version: QrVersions.auto).toImageData(120);
      return b?.buffer.asUint8List(b.offsetInBytes, b.lengthInBytes);
    } catch (_) {
      return null;
    }
  }
}

