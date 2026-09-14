import 'dart:io';
import '../lib/services/sheet_parser.dart';

void main(List<String> args) {
  final fp = args[0];
  final bytes = File(fp).readAsBytesSync();
  final sheets = SheetParser.parse(bytes);
  var tot = 0;
  for (final s in sheets) {
    final rows = MapelMapper.fromRows(s.rows);
    tot += rows.length;
    print('${s.name}: ${rows.length} mapel');
    for (final r in rows.take(6)) {
      print('  ${r['nama']} ${r['kode'] ?? ''} ${r['img'] ?? ''}');
    }
  }
  print('TOTAL $tot');
}
