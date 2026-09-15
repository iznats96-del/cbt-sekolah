import 'dart:io';
import 'package:supabase/supabase.dart';

Future<void> main() async {
  final anon = Platform.environment['ANON']!;
  final url = 'https://yukqngrtgevveimhrwke.supabase.co';
  final client = SupabaseClient(url, anon);
  await client.auth.signInWithPassword(
      email: '0099160915@cbt.local', password: 'YP8014');
  // varian 1: TANPA params (persis kode v15 beranda)
  try {
    final r1 = await client.rpc('my_ujian_aktif');
    print('TANPA params: OK → ${r1.toString().substring(0, 80)}');
  } catch (e) {
    print('TANPA params: ERROR → $e');
  }
  // varian 2: params map kosong (fix yang diajukan)
  try {
    final r2 = await client.rpc('my_ujian_aktif', params: {});
    print('params {}    : OK → ${r2.toString().substring(0, 80)}');
  } catch (e) {
    print('params {}    : ERROR → $e');
  }
  await client.dispose();
}
