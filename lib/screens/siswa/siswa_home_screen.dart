import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import 'ujian_beranda_list.dart';

Widget _chip(IconData icon, String t) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: const Color(0xFFEAF3FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCFE4F5))),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.primary),
        const SizedBox(width: 4),
        Text(t,
            style: const TextStyle(
                fontSize: 11, color: Color(0xFF0F3A5F), fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class SiswaHomeScreen extends StatefulWidget {
  const SiswaHomeScreen({super.key});

  @override
  State<SiswaHomeScreen> createState() => _SiswaHomeScreenState();
}

class _SiswaHomeScreenState extends State<SiswaHomeScreen> {
  Map<String, dynamic>? _profil;
  Map<String, dynamic>? _siswaRow;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await Api.currentProfile();
    Map<String, dynamic>? row;
    try {
      final rows = await Api.client
          .from('siswa')
          .select('nama,nis,nisn,aktive_ok,kelas(nama,jurusan(singkatan))')
          .eq('profile_id', Api.user?.id ?? '')
          .limit(1);
      if (rows.isNotEmpty) row = Map<String, dynamic>.from(rows.first as Map);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _profil = p;
      _siswaRow = row;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 26,
                  child: Icon(Icons.person, size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _siswaRow?['nama']?.toString() ??
                            _profil?['nama']?.toString() ??
                            'Siswa',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _chip(Icons.badge_outlined,
                              'NIS ${_siswaRow?['nis'] ?? _profil?['nis'] ?? '-'}'),
                          if ((_siswaRow?['kelas'] is Map) &&
                              (_siswaRow!['kelas']['nama'] != null))
                            _chip(Icons.groups_outlined,
                                '${_siswaRow!['kelas']['nama']}'
                                '${(_siswaRow!['kelas']['jurusan'] is Map) ? ' • ${_siswaRow!['kelas']['jurusan']['singkatan']}' : ''}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text('UJIAN TERSEDIA',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 1)),
        ),
        const UjianBerandaList(),
      ],
    );
  }
}