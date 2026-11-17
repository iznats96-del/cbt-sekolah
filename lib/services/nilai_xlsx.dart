import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import 'xlsx_patch.dart';

/// Facade: memuat template dari asset lalu memanggil [XlsxPatch] (Dart murni).
class NilaiXlsx {
  NilaiXlsx._();

  static String templatePath(String tingkat) =>
      'assets/templates/FORMAT NILAI $tingkat (MAPEL) ASTS GANJIL 2627.xlsx';

  static Future<List<String>> sheetNames(String tingkat) async {
    final bytes = await _bytes(tingkat);
    return XlsxPatch.sheetNames(bytes);
  }

  static Future<Uint8List> build({
    required String tingkat,
    required String sheetName,
    required String mapel,
    required Map<String, num> nilaiByNama,
  }) async {
    final bytes = await _bytes(tingkat);
    return XlsxPatch.build(
      templateBytes: bytes,
      sheetName: sheetName,
      mapel: mapel,
      nilaiByNama: nilaiByNama,
    );
  }

  static Future<Uint8List> _bytes(String tingkat) async {
    final data = await rootBundle.load(templatePath(tingkat));
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}
