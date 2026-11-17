import 'package:flutter/material.dart';

import '../services/api.dart';
import '../screens/shared/cetak_peserta_screen.dart';

/// Dipakai dashboard admin & panitia: pilih ujian lalu buka layar cetak kartu.
Future<void> pilihDanCetakKartu(BuildContext context) async {
  List<Map<String, dynamic>> ujian = [];
  try {
    ujian = await Api.routerSelect(
      'ujian',
      select: 'id,nama,tanggal,status',
      order: 'tanggal',
      ascending: false,
      limit: 50,
    );
  } catch (_) {}
  if (!context.mounted) return;
  if (ujian.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Belum ada ujian. Buat ujian dulu ya.'),
    ));
    return;
  }
  Map<String, dynamic>? pilih = ujian.first;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(builder: (c, setS) {
      return AlertDialog(
        title: const Text('Cetak Kartu Peserta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pilih ujian yang akan dicetak kartunya:',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: pilih?['id']?.toString(),
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Ujian'),
              items: ujian
                  .map((u) => DropdownMenuItem<String>(
                        value: u['id'].toString(),
                        child: Text(
                          '${u['nama']} • ${u['status'] ?? ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: (v) => setS(() {
                pilih = ujian.firstWhere((u) => u['id'].toString() == v);
              }),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Cetak'),
          ),
        ],
      );
    }),
  );
  if (ok != true || pilih == null || !context.mounted) return;
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => CetakPesertaScreen(ujian: Map<String, dynamic>.from(pilih!)),
  ));
}
