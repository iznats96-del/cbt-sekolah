import 'package:flutter/material.dart';

import '../../services/api.dart';
import '../../services/file_saver.dart';
import '../../services/kartu_siswa_pdf.dart';
import '../../widgets/dashboard_header.dart';

/// Cetak KARTU PESERTA CBT per siswa (bukan kartu ujian).
/// Sumber: tabel siswa, profiles.pw_default, sekolah.
class CetakKartuSiswaScreen extends StatefulWidget {
  const CetakKartuSiswaScreen({super.key});

  @override
  State<CetakKartuSiswaScreen> createState() => _CetakKartuSiswaScreenState();
}

class _CetakKartuSiswaScreenState extends State<CetakKartuSiswaScreen> {
  List<Map<String, dynamic>> _siswa = [];
  Map<String, String> _pw = {};
  Map<String, dynamic> _sekolah = {};
  final Set<String> _pilih = {};
  String _cari = '';
  bool _loading = true;
  bool _printing = false;
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
      final rows = await Api.routerSelect(
        'siswa',
        select:
            'id,profile_id,nama,nis,nomor_peserta,foto_url,kelas(nama,jurusan(singkatan))',
        order: 'nama',
        limit: 1000,
      );
      final prof = await Api.routerSelect('profiles',
          select: 'id,pw_default', limit: 1000).catchError((_) => <Map<String, dynamic>>[]);
      final sk = await Api.routerSelect('sekolah',
          select: 'nama,kepala_sekolah,nip_kepala', limit: 1).catchError((_) => <Map<String, dynamic>>[]);
      if (!mounted) return;
      setState(() {
        _siswa = rows;
        _pw = {
          for (final p in prof) '${p['id']}': '${p['pw_default'] ?? ''}'
        };
        _sekolah = sk.isNotEmpty ? Map<String, dynamic>.from(sk.first) : {};
        _pilih
          ..clear()
          ..addAll(rows.map((r) => r['id'].toString()));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat data siswa: $e';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _difilter {
    final q = _cari.trim().toLowerCase();
    if (q.isEmpty) return _siswa;
    return _siswa.where((s) {
      final k = s['kelas'];
      final kelas = k is Map ? '${k['nama'] ?? ''}' : '';
      return '${s['nama'] ?? ''} ${s['nis'] ?? ''} ${s['nomor_peserta'] ?? ''} $kelas'
          .toLowerCase()
          .contains(q);
    }).toList();
  }

  KartuSiswaData _keKartu(Map<String, dynamic> s) {
    final k = s['kelas'];
    final kelas = k is Map ? '${k['nama'] ?? ''}' : '';
    final jur = k is Map && k['jurusan'] is Map
        ? '${(k['jurusan'] as Map)['singkatan'] ?? ''}'
        : '';
    final nis = '${s['nis'] ?? ''}';
    return KartuSiswaData(
      noPeserta: '${s['nomor_peserta'] ?? ''}',
      nama: '${s['nama'] ?? ''}',
      kelas: jur.isNotEmpty ? '$kelas â€¢ $jur' : kelas,
      username: nis,
      password: _pw['${s['profile_id']}'] ?? '',
      fotoUrl: '${s['foto_url'] ?? ''}',
      qrData: nis,
    );
  }

  Future<void> _cetak() async {
    final list = _siswa.where((s) => _pilih.contains(s['id'].toString())).toList();
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pilih minimal satu siswa')));
      return;
    }
    setState(() => _printing = true);
    try {
      final pdf = await KartuSiswaPdf.build(
        cards: [for (final s in list) _keKartu(s)],
        sekolah: '${_sekolah['nama'] ?? 'SMK YP 79 Majalaya'}',
        kepala: '${_sekolah['kepala_sekolah'] ?? ''}',
        nip: '${_sekolah['nip_kepala'] ?? ''}',
      );
      await saveBytes(pdf, 'KARTU PESERTA SISWA (${list.length}).pdf');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Kartu ${list.length} siswa siap dicetak'),
        backgroundColor: Colors.teal,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal buat kartu: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _difilter;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      body: Column(
        children: [
          DashboardHeader(
            title: 'CETAK KARTU SISWA',
            subtitle: 'Kartu Peserta CBT â€¢ ${KartuSiswaPdf.tahunAjaran()}',
            showBack: true,
            stats: [
              ('siswa', '${_siswa.length}'),
              ('dipilih', '${_pilih.length}'),
            ],
            actions: [
              IconButton(
                onPressed: _load,
                tooltip: 'Muat ulang',
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!, textAlign: TextAlign.center),
                        ),
                      )
                    : Column(children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.06),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: TextField(
                              onChanged: (v) => setState(() => _cari = v),
                              decoration: InputDecoration(
                                hintText: 'Cari nama, NIS, atau kelasâ€¦',
                                prefixIcon: const Icon(Icons.search_rounded,
                                    color: Color(0xFF2563EB)),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 6, 16, 6),
                          child: Row(
                            children: [
                              const Icon(Icons.groups_outlined,
                                  size: 16, color: Color(0xFF2563EB)),
                              const SizedBox(width: 8),
                              Text(
                                'Daftar siswa (${list.length})',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF101F3C)),
                              ),
                              const Spacer(),
                              _miniBtn(
                                  label: 'Semua',
                                  onTap: () => setState(() => _pilih
                                    ..clear()
                                    ..addAll(list.map((r) => r['id'].toString())))),
                              const SizedBox(width: 6),
                              _miniBtn(
                                  label: 'Kosongkan',
                                  onTap: () => setState(() => _pilih.clear())),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                            itemCount: list.length,
                            itemBuilder: (_, i) => _SiswaRow(
                              data: list[i],
                              selected: _pilih.contains(list[i]['id'].toString()),
                              password: _pw['${list[i]['profile_id']}'] ?? '-',
                              onTap: () {
                                final id = list[i]['id'].toString();
                                setState(() {
                                  if (_pilih.contains(id)) _pilih.remove(id);
                                  else _pilih.add(id);
                                });
                              },
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
                                blurRadius: 18,
                                offset: const Offset(0, -4),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            top: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                              child: SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF0EA5A4),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14)),
                                  ),
                                  onPressed: _printing ? null : _cetak,
                                  icon: _printing
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.print_rounded),
                                  label: Text(
                                    'Cetak Kartu (${_pilih.length})',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ]),
          ),
        ],
      ),
    );
  }

  Widget _miniBtn({required String label, required VoidCallback onTap}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F1FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2563EB))),
        ),
      );
}

class _SiswaRow extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool selected;
  final String password;
  final VoidCallback onTap;
  const _SiswaRow({
    required this.data,
    required this.selected,
    required this.password,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final k = data['kelas'];
    final kelas = k is Map ? '${k['nama'] ?? ''}' : '';
    final jur = k is Map && k['jurusan'] is Map
        ? '${(k['jurusan'] as Map)['singkatan'] ?? ''}'
        : '';
    final nama = '${data['nama'] ?? ''}';
    final inisial = nama
        .trim()
        .split(RegExp(r'\s+'))
        .take(2)
        .map((e) => e.isEmpty ? '' : e[0])
        .join()
        .toUpperCase();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF2563EB) : const Color(0xFFE7EDFA),
            width: selected ? 1.8 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E3A8A).withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFE8F1FF),
              child: Text(inisial.isEmpty ? '?' : inisial,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2563EB))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nama,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF101F3C))),
                  const SizedBox(height: 4),
                  Text(
                    'NIS ${data['nis']} â€¢ ${jur.isNotEmpty ? '$kelas â€¢ $jur' : kelas}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF8A97B1)),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(password,
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF3D5873))),
            ),
            const SizedBox(width: 10),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF2563EB) : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFB8C4D9),
                  width: 1.6,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

