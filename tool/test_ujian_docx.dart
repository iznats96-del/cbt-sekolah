import 'dart:io';
import '../lib/services/ujian_docx_parser.dart';

void main(List<String> args) {
  final fp = args[0];
  final u = UjianDocxParser.parse(File(fp).readAsBytesSync());
  print('MAPEL  : ${u.mapel}');
  print('KELAS  : ${u.kelas}');
  print('JUDUL  : ${u.judul}');
  print('WAKTU  : ${u.waktuMenit}');
  print('GURU   : ${u.guru}');
  print('PG     : ${u.pg.length}');
  if (u.pg.isNotEmpty) {
    print('  [1] ${u.pg[0].soal}');
    print('      opsi: ${u.pg[0].opsi}');
    print('      kunci: ${u.pg[0].kunci}');
    print('  [45] ${u.pg[44 < u.pg.length ? 44 : u.pg.length-1].soal}');
  }
  print('JODOH  : ${u.jodoh.length}');
  if (u.jodoh.isNotEmpty) {
    print('  [1] ${u.jodoh.first.soal}');
    print('  opsi: ${u.jodoh.first.opsi}');
  }
  print('ESSAY  : ${u.essay.length}');
  if (u.essay.isNotEmpty) print('  [1] ${u.essay.first.soal}');
  print('WARN   : ${u.warnings}');
}
