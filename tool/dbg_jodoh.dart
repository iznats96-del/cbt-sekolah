import 'dart:io';
import '../lib/services/ujian_docx_parser.dart';
void main(List<String> args) {
  final u = UjianDocxParser.parse(File(args[0]).readAsBytesSync());
  print('PG=${u.pg.length} ESSAY=${u.essay.length} WARN=${u.warnings}');
}
