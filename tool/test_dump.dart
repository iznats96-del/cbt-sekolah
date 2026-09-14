import 'dart:io';
import '../lib/services/sheet_parser.dart';
void main() {
  final bytes = File('/data/data/com.termux/files/home/.cache/opencode/tmp/m2.docx').readAsBytesSync();
  for (final s in SheetParser.parse(bytes)) {
    print('IMAGES: ${s.images.keys.toList()}');
    for (final r in s.rows) {
      print(r.map((c) => c.length > 70 ? c.substring(0, 70) + '…' : c).toList());
    }
  }
}
