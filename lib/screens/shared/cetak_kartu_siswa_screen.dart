import 'package:flutter/material.dart';

import '../../services/api.dart';
import '../../services/file_saver.dart';
import '../../services/kartu_siswa_pdf.dart';

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
      kelas: jur.isNotEmpty ? '$kelas • $jur' : kelas,
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
      appBar: AppBar(
        title: const Text('Cetak Kartu Siswa'),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: 'Muat ulang',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: TextField(
                        onChanged: (v) => setState(() => _cari = v),
                        decoration: InputDecoration(
                          hintText: 'Cari nama / NIS / kelas…',
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Text('${_pilih.length} terpilih dari ${_siswa.length} siswa',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                          const Spacer(),
                          TextButton(
                            onPressed: () => setState(() => _pilih
                              ..clear()
                              ..addAll(list.map((r) => r['id'].toString()))),
                            child: const Text('Pilih semua'),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _pilih.clear()),
                            child: const Text('Kosongkan'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final s = list[i];
                          final id = s['id'].toString();
                          final k = s['kelas'];
                          final kelas = k is Map ? '${k['nama'] ?? ''}' : '';
                          return CheckboxListTile(
                            value: _pilih.contains(id),
                            onChanged: (v) => setState(() {
                              if (v == true) _pilih.add(id);
                              else _pilih.remove(id);
                            }),
                            title: Text('${s['nama']}',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                'NIS ${s['nis']} • $kelas • ${_pw['${s['profile_id']}'] ?? '-'}',
                                style: const TextStyle(fontSize: 11)),
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: FilledButton.icon(
                            onPressed: _printing ? null : _cetak,
                            icon: _printing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.print),
                            label: Text('Cetak Kartu (${_pilih.length})'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
