import 'dart:io';
import '../lib/services/ujian_docx_parser.dart';
void main() {
  final u = UjianDocxParser.parse(File('/data/data/com.termux/files/home/.cache/opencode/tmp/s1.docx').readAsBytesSync());
  for (var i = 0; i < u.jodoh.length; i++) {
    final j = u.jodoh[i];
    print('J$i opsi=${j.opsi.length} :: ${j.soal.substring(0, j.soal.length > 45 ? 45 : j.soal.length)}');
  }
}
