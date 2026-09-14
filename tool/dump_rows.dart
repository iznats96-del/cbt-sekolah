import 'dart:convert';
import 'dart:io';
import '../lib/services/sheet_parser.dart';

void main() {
  final bytes = File('/data/data/com.termux/files/home/.cache/opencode/tmp/abs.xls').readAsBytesSync();
  final tables = SiswaImportMapper.fromSheets(SheetParser.parse(bytes))
      .where((t) => t.rows.isNotEmpty).toList();
  final rows = <Map<String, String>>[];
  for (final t in tables) {
    for (final r in t.rows) {
      rows.add({
        'nis': r['nis'] ?? '',
        'nisn': r['nisn'] ?? '',
        'nama': r['nama'] ?? '',
        'jk': r['jk'] ?? '',
        'kelas': (r['kelas']?.isNotEmpty ?? false) ? r['klass'] ?? t.kelas : t.kelas,
        'tingkat': '${t.tingkat ?? ''}',
      });
    }
  }
  File('/data/data/com.termux/files/home/.cache/opencode/tmp/rows.json').writeAsStringSync(jsonEncode(rows));
  print('rows: ${rows.length}');
}
