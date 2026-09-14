import 'dart:io';
import '../lib/services/sheet_parser.dart';

void main(List<String> args) {
  final fp = args.isEmpty ? '/data/data/com.termux/files/home/.cache/opencode/tmp/abs.xls' : args[0];
  final bytes = File(fp).readAsBytesSync();
  final sheets = SheetParser.parse(bytes);
  print('sheets=${sheets.length}');
  for (final s in sheets) {
    print('--- ${s.name} rows=${s.rows.length}');
    for (final r in s.rows.take(3)) {
      print('   ${r.take(5).toList()}');
    }
  }
  final tables = SiswaImportMapper.fromSheets(sheets)
      .where((t) => t.rows.isNotEmpty)
      .toList();
  print('tables=${tables.length}');
  var total = 0;
  for (final t in tables) {
    total += t.rows.length;
    print('${t.kelas} tingkat=${t.tingkat} n=${t.rows.length} sample=${t.rows.take(2).toList()}');
  }
  print('TOTAL SISWA = ${tables.fold(0, (a, t) => a + t.rows.length)}');
}