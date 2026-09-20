import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';

/// Kartu QR murid — isinya NIS. Ditunjukkan ke guru saat absen scan.
class KartuSayaScreen extends StatefulWidget {
  const KartuSayaScreen({super.key});

  @override
  State<KartuSayaScreen> createState() => _KartuSayaScreenState();
}

class _KartuSayaScreenState extends State<KartuSayaScreen> {
  Map<String, dynamic>? _siswa;
  List<Map<String, dynamic>> _nomor = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await Api.client
          .from('siswa')
          .select('id,nama,nis,nomor_peserta,kelas(nama)')
          .eq('profile_id', Api.user?.id ?? '')
          .limit(1);
      List<Map<String, dynamic>> nomor = [];
      if (rows.isNotEmpty) {
        final sid = '${(rows.first as Map)['id'] ?? ''}';
        if (sid.isNotEmpty) {
          try {
            final pr = await Api.client
                .from('peserta_ujian')
                .select('nomor_peserta,ujian(nama)')
                .eq('siswa_id', sid)
                .not('nomor_peserta', 'is', null)
                .order('nomor_peserta')
                .limit(20);
            nomor = List<Map<String, dynamic>>.from(pr);
          } catch (_) {}
        }
      }
      if (!mounted) return;
      setState(() {
        _siswa =
            rows.isNotEmpty ? Map<String, dynamic>.from(rows.first) : null;
        _nomor = nomor;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final nis = '${_siswa?['nis'] ?? ''}';
    if (nis.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Data siswa belum terhubung.\nHubungi admin/wali kelas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }
    final nama = '${_siswa?['nama'] ?? 'Siswa'}';
    final kelas = _siswa?['kelas'] is Map
        ? '${(_siswa!['kelas'] as Map)['nama'] ?? ''}'
        : '';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.badge_outlined,
                    size: 40, color: AppTheme.primary),
                const SizedBox(height: 8),
                const Text('KARTU ABSEN SAYA',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: QrImageView(
                    data: nis,
                    version: QrVersions.auto,
                    size: 230,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(nama,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('NIS $nis${kelas.isNotEmpty ? ' • $kelas' : ''}',
                    style:
                        TextStyle(fontSize: 13, color: Colors.grey[600])),
                const SizedBox(height: 12),
                const Text(
                  'Tunjukkan QR ini ke guru saat absen.\nQR ini = NIS kamu, jangan disebar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        if (_nomor.isEmpty && '${_siswa?['nomor_peserta'] ?? ''}'.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.confirmation_number_outlined,
                      size: 20, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('NOMOR PESERTA',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                                letterSpacing: 1)),
                        Text('${_siswa?['nomor_peserta']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: AppTheme.primary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_nomor.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.confirmation_number_outlined,
                          size: 18, color: AppTheme.primary),
                      SizedBox(width: 8),
                      Text('NOMOR PESERTA UJIAN',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 1)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                      'TKJ-1-2627-01 = Jurusan-Semester(1 Ganjil/2 Genap)-Tahun-Urut abjad per jurusan',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 8),
                  for (final n in _nomor)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text('${n['nomor_peserta']}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppTheme.primary)),
                                Text(
                                    '${(n['ujian'] is Map ? (n['ujian'] as Map)['nama'] : '') ?? ''}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
