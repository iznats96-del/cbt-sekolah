import 'package:flutter/material.dart';

import '../screens/shared/cetak_kartu_siswa_screen.dart';

/// Dashboard admin/panitia → layar cetak KARTU PESERTA SISWA.
/// Kartu siswa TIDAK terikat ujian (sumber: tabel siswa).
Future<void> pilihDanCetakKartu(BuildContext context) {
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => const CetakKartuSiswaScreen(),
  ));
}
