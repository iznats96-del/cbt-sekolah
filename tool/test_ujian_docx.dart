import 'dart:io';
import '../lib/services/ujian_docx_parser.dart';

void main(List<String> args) {
  final u = UjianDocxParser.parse(File(args[0]).readAsBytesSync());
  print('MAPEL: ${u.mapel} | KELAS: ${u.kelas} | JUDUL: ${u.judul} | WAKTU: ${u.waktuMenit} | GURU: ${u.guru}');
  print('PG=${u.pg.length} ESSAY=${u.essay.length} KUNCI=${u.pg.where((p) => p.kunci != null).length}');
  for (final p in u.pg.take(3)) {
    print(' Q: ${p.soal.length > 70 ? p.soal.substring(0, 70) : p.soal}');
    print('   O: ${p.opsi.map((o) => o.length > 28 ? '${o.substring(0, 28)}…' : o).toList()}  K=${p.kunci}');
  }
  if (u.pg.length > 3) {
    final p = u.pg[u.pg.length - 1];
    print(' QTERAKHIR: ${p.soal.substring(0, p.soal.length > 70 ? 70 : p.soal.length)} O=${p.opsi.length}');
  }
  if (u.essay.isNotEmpty) print(' ES1: ${u.essay.first.soal}');
  print('WARN: ${u.warnings}');
}
