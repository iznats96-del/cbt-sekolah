import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../lib/services/ujian_docx_parser.dart';

Future<void> main(List<String> args) async {
  final anon = Platform.environment['ANON']!;
  const base = 'https://yukqngrtgevveimhrwke.supabase.co';
  final lr = await http.post(Uri.parse('$base/auth/v1/token?grant_type=password'),
      headers: {'apikey': anon, 'Content-Type': 'application/json'},
      body: jsonEncode({'email': 'admin@cbt.sekolah', 'password': 'Admin123!'}));
  final admin = (jsonDecode(lr.body)["access_token"]) as String;
  final doc = UjianDocxParser.parse(File('/data/data/com.termux/files/home/.cache/opencode/tmp/sb.docx').readAsBytesSync());
  final kr = await http.get(Uri.parse('$base/rest/v1/kelas?select=id,nama&nama=eq.X%20TKJ%201'),
      headers: {'apikey': anon, 'Authorization': 'Bearer $admin'});
  final kelasId = (jsonDecode(kr.body) as List).first['id'] as String;
  final items = <Map<String, dynamic>>[];
  for (final p in doc.pg) {
    items.add({'jenis': 'pg', 'soal': p.soal, 'opsi': p.opsi, 'kunci': null, 'bobot': '1'});
  }
  for (final e in doc.essay) {
    items.add({'jenis': 'essay', 'soal': e.soal, 'opsi': null, 'kunci': null, 'bobot': '1'});
  }
  final r = await http.post(Uri.parse('$base/rest/v1/rpc/admin_import_ujian_docx'),
      headers: {'apikey': anon, 'Authorization': 'Bearer $admin', 'Content-Type': 'application/json'},
      body: jsonEncode({'p_payload': {
        'mapel': doc.mapel, 'jurusan': 'AKUNTANSI', 'kelas': 'X', 'kelas_id': kelasId,
        'judul': doc.judul, 'waktu': '${doc.waktuMenit ?? 60}', 'token': 'SEN9', 'guru': doc.guru,
        'jenis_ujian': 'ASESMEN SUMATIF AKHIR TAHUN', 'items': items
      }}));
  print('IMPORT SB: ${r.statusCode} ${(r.body.length>160?r.body.substring(0,160):r.body)}');
  print('parser: mapel=${doc.mapel} pg=${doc.pg.length} jodoh=${doc.jodoh.length} essay=${doc.essay.length}');
}
