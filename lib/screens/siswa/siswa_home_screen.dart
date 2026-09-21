import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import 'ujian_beranda_list.dart';
import 'kartu_saya_screen.dart';

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
          .select('nama,nis,nomor_peserta,aktive_ok,kelas(nama,jurusan(singkatan))')
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

  void _salinNomor(String n) async {
    await Clipboard.setData(ClipboardData(text: n));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nomor peserta tersalin'),
        backgroundColor: AppTheme.secondary));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final nomor = '${_siswaRow?['nomor_peserta'] ?? ''}';
    final nama = _siswaRow?['nama']?.toString() ??
        _profil?['nama']?.toString() ??
        'Siswa';
    final nis = '${_siswaRow?['nis'] ?? _profil?['nis'] ?? '-'}';
    final kelasVal = _siswaRow?['kelas'] is Map
        ? '${(_siswaRow!['kelas'] as Map)['nama'] ?? ''}'
        : '';
    final jur = _siswaRow?['kelas'] is Map &&
            (_siswaRow!['kelas']['jurusan'] is Map)
        ? '${(_siswaRow!['kelas']['jurusan'] as Map)['singkatan'] ?? ''}'
        : '';

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A6DB4), Color(0xFF2E9B8F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF1A6DB4).withOpacity(0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8)
                          ]),
                      child: const CircleAvatar(
                        radius: 26,
                        backgroundColor: Color(0xFFEAF3FB),
                        child: Icon(Icons.person,
                            size: 30, color: AppTheme.primary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nama,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _chipWhite(
                                  Icons.badge_outlined, 'NIS $nis'),
                              if (kelasVal.isNotEmpty)
                                _chipWhite(Icons.groups_outlined,
                                    jur.isNotEmpty ? '$kelasVal • $jur' : kelasVal),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: nomor.isEmpty
                      ? const Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 18, color: Colors.grey),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                  'Nomor peserta belum terbit — hubungi wali/admin',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey)),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.confirmation_number_outlined,
                                    size: 14, color: AppTheme.primary),
                                SizedBox(width: 6),
                                Text('NOMOR PESERTA',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primary,
                                        letterSpacing: 1.2)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Text(nomor,
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                          letterSpacing: 1.2)),
                                ),
                                IconButton(
                                  tooltip: 'Salin nomor',
                                  visualDensity:
                                      VisualDensity.compact,
                                  onPressed: () => _salinNomor(nomor),
                                  icon: const Icon(
                                      Icons.copy_outlined,
                                      size: 18,
                                      color: AppTheme.primary),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                                'TKJ-1-2627-01 = Jurusan-Semester(1=Ganjil)-Tahun-Urut per jurusan',
                                style: TextStyle(
                                    fontSize: 10, color: Colors.grey)),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primary,
                                  side: const BorderSide(
                                      color: Color(0xFFE2E8F0)),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10),
                                ),
                                onPressed: () => Navigator.of(context)
                                    .push(MaterialPageRoute(
                                        builder: (_) =>
                                            const KartuSayaScreen())),
                                icon: const Icon(Icons.qr_code_2,
                                    size: 18),
                                label: const Text('Lihat Kartu dan QR',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
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
        const SizedBox(height: 20),
      ],
    );
  }
}

Widget _chipWhite(IconData icon, String t) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withOpacity(0.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Colors.white),
        const SizedBox(width: 4),
        Text(t,
            style: const TextStyle(
                fontSize: 10.5,
                color: Colors.white,
                fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
