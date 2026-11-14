import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../lib/services/ujian_docx_parser.dart';

// Alur SAMA seperti aplikasi: login -> parse docx -> RPC import
Future<void> main(List<String> args) async {
  const base = 'https://yukqngrtgevveimhrwke.supabase.co';
  final anon = Platform.environment['ANON']!;

  final loginRes = await http.post(
    Uri.parse('$base/auth/v1/token?grant_type=password'),
    headers: {'apikey': anon, 'Content-Type': 'application/json'},
    body: jsonEncode({'email': 'admin@cbt.sekolah', 'password': 'Admin123!'}),
  );
  if (loginRes.statusCode != 200) {
    stderr.writeln('login gagal: ${loginRes.body}');
    exit(1);
  }
  final token = jsonDecode(loginRes.body)['access_token'] as String;
  stderr.writeln('login admin OK');

  final doc = UjianDocxParser.parse(
      File('/data/data/com.termux/files/home/.cache/opencode/tmp/s1.docx').readAsBytesSync());
  stderr.writeln(
      'parse: mapel=${doc.mapel} kelas=${doc.kelas} pg=${doc.pg.length} '
      'essay=${doc.essay.length} warn=${doc.warnings}');

  final items = <Map<String, dynamic>>[];
  for (final p in doc.pg) {
    items.add({
      'jenis': 'pg', 'soal': p.soal, 'opsi': p.opsi,
      'kunci': null, 'bobot': '1',
    });
  }
  for (final e in doc.essay) {
    items.add({
      'jenis': 'essay', 'soal': e.soal,
      'opsi': null, 'kunci': null, 'bobot': '1',
    });
  }

  final r = await http.post(
    Uri.parse('$base/rest/v1/rpc/admin_import_ujian_docx'),
    headers: {
      'apikey': anon,
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'p_payload': {
        'mapel': doc.mapel,
        'jurusan': doc.jurusan ?? 'TKJ',
        'kelas': doc.kelas,
        'judul': doc.judul,
        'waktu': '${doc.waktuMenit ?? 60}',
        'token': 'REAL79',
        'guru': doc.guru,
        'jenis_ujian': 'Penilaian Sumatif',
        'items': items,
      }
    }),
  );
  print('IMPORT RESULT (${r.statusCode}): ${r.body}');
}
