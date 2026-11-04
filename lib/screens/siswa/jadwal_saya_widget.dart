import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';

class JadwalSayaWidget extends StatefulWidget {
  const JadwalSayaWidget({super.key});

  @override
  State<JadwalSayaWidget> createState() => _JadwalSayaWidgetState();
}

class _JadwalSayaWidgetState extends State<JadwalSayaWidget> {
  List<Map<String, dynamic>> _jadwal = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await Api.client.rpc('jadwal_siswa_aktif');
      if (!mounted) return;
      dynamic data = raw;
      if (data is String) data = jsonDecode(data);
      setState(() {
        _jadwal = List<Map<String, dynamic>>.from(data as List);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat jadwal: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }
    if (_jadwal.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Belum ada jadwal ujian untuk kelasmu.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 18, color: AppTheme.secondary),
              const SizedBox(width: 8),
              const Text(
                'Jadwal Ujian Kelasku',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Muat ulang',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _jadwal.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final j = _jadwal[i];
            final sesiNama = j['sesi_nama']?.toString() ?? '-';
            final jamMulai = j['jam_mulai']?.toString() ?? '';
            final jamSelesai = j['jam_selesai']?.toString() ?? '';
            final jamStr = (jamMulai.isNotEmpty && jamSelesai.isNotEmpty)
                ? '$jamMulai - $jamSelesai'
                : null;
            final ruangNama = j['ruang_nama']?.toString();
            final tanggal = j['tanggal']?.toString() ?? '-';
            return Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      j['ujian_nama'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if ((j['mapel'] ?? '').toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${j['mapel']}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                      ),
                    const SizedBox(height: 8),
                    _infoRow(Icons.event, 'Tanggal', tanggal),
                    _infoRow(Icons.access_time, 'Sesi', sesiNama),
                    if (jamStr != null) _infoRow(Icons.schedule, 'Jam', jamStr),
                    if (ruangNama != null && ruangNama.isNotEmpty)
                      _infoRow(Icons.meeting_room_outlined, 'Ruang', ruangNama),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 6),
          Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}