import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/api.dart';

/// ─────────────────────────────────────────────────────────────
/// Kartu Absensi Siswa — Modern CBT (rujukan desain user)
/// ─────────────────────────────────────────────────────────────
/// Data asli dari tabel siswa: nama, nis, nomor_peserta, foto_url, kelas.
/// QR berisi NIS (sama seperti sebelumnya) — dipakai guru saat scan absen.
/// Field yang NULL tidak ditampilkan. Tidak ada data dummy.
/// ─────────────────────────────────────────────────────────────

const _bg = Color(0xFFF4F7FF);
const _navy = Color(0xFF101F3C);
const _navySoft = Color(0xFF3B4B6B);
const _muted = Color(0xFF8A97B1);
const _blue = Color(0xFF2563EB);
const _blueDeep = Color(0xFF1D4ED8);
const _blueLight = Color(0xFFE8F1FF);
const _line = Color(0xFFE7EDFA);

class KartuSayaScreen extends StatefulWidget {
  final bool embedded;
  const KartuSayaScreen({super.key, this.embedded = false});

  @override
  State<KartuSayaScreen> createState() => _KartuSayaScreenState();
}

class _KartuSayaScreenState extends State<KartuSayaScreen> {
  Map<String, dynamic>? _siswa;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await Api.routerSelect(
      'siswa',
      select: 'id,nama,nis,nomor_peserta,foto_url,kelas(nama,jurusan(singkatan))',
      eq: {'profile_id': Api.user?.id ?? ''},
      limit: 1,
    ).catchError((_) => <Map<String, dynamic>>[]);
    if (!mounted) return;
    setState(() {
      if (rows.isNotEmpty) _siswa = Map<String, dynamic>.from(rows.first);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      final loading = Center(
          child: CircularProgressIndicator(color: _blue));
      if (widget.embedded) return loading;
      return Scaffold(backgroundColor: _bg, body: loading);
    }

    final s = _siswa ?? const {};
    final nis = '${s['nis'] ?? ''}';
    final nama = '${s['nama'] ?? 'Siswa'}';
    final nomor = '${s['nomor_peserta'] ?? ''}';
    final foto = '${s['foto_url'] ?? ''}';
    final kelasMap = s['kelas'];
    final kelas = kelasMap is Map ? '${kelasMap['nama'] ?? ''}' : '';
    final jur = kelasMap is Map && kelasMap['jurusan'] is Map
        ? '${(kelasMap['jurusan'] as Map)['singkatan'] ?? ''}'
        : '';

    if (nis.isEmpty) {
      if (widget.embedded) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Data siswa belum terhubung.\nHubungi admin/wali kelas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted),
            ),
          ),
        );
      }
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: const Text('Kartu Absensi'),
          backgroundColor: _blueDeep,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Data siswa belum terhubung.\nHubungi admin/wali kelas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted),
            ),
          ),
        ),
      );
    }

    final content = ListView(
      padding: widget.embedded
          ? const EdgeInsets.fromLTRB(16, 12, 16, 28)
          : EdgeInsets.zero,
      children: [
        if (!widget.embedded) _AppBar(namaHalaman: 'Kartu Absensi'),
        Padding(
          padding: widget.embedded
              ? EdgeInsets.zero
              : const EdgeInsets.fromLTRB(16, 0, 16, 28),
          child: widget.embedded
              ? _Kartu(
                  nama: nama,
                  nis: nis,
                  nomor: nomor,
                  foto: foto,
                  kelas: kelas,
                  jur: jur,
                )
              : Transform.translate(
                  offset: const Offset(0, -22),
                  child: _Kartu(
                    nama: nama,
                    nis: nis,
                    nomor: nomor,
                    foto: foto,
                    kelas: kelas,
                    jur: jur,
                  ),
                ),
        ),
      ],
    );
    if (widget.embedded) return content;
    return Scaffold(backgroundColor: _bg, body: content);
  }
}

class _AppBar extends StatelessWidget {
  final String namaHalaman;
  const _AppBar({required this.namaHalaman});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_blueDeep, _blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -40,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  shape: BoxShape.circle),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 30, 20, 56),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  tooltip: 'Kembali',
                ),
                Expanded(
                  child: Text(
                    namaHalaman,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Kartu extends StatelessWidget {
  final String nama, nis, nomor, foto, kelas, jur;

  const _Kartu({
    required this.nama,
    required this.nis,
    required this.nomor,
    required this.foto,
    required this.kelas,
    required this.jur,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.08),
            blurRadius: 28,
            spreadRadius: 1,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // dekorasi lengkungan biru muda
          Positioned(
            right: -50,
            top: -30,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                color: _blue.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            children: [
              const SizedBox(height: 26),
              // Foto dengan cincin biru
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: _blue, shape: BoxShape.circle),
                child: CircleAvatar(
                  radius: 54,
                  backgroundColor: _blueLight,
                  backgroundImage: foto.isNotEmpty ? NetworkImage(foto) : null,
                  child: foto.isEmpty
                      ? const Icon(Icons.person_rounded, size: 54, color: _blue)
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                nama.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                [
                  'NIS $nis',
                  if (kelas.isNotEmpty)
                    (jur.isNotEmpty ? '$kelas • $jur' : kelas),
                ].join('  •  '),
                style: const TextStyle(fontSize: 13, color: _navySoft),
              ),
              const SizedBox(height: 22),

              // QR: NIS asli
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 44),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _line),
                  ),
                  child: QrImageView(
                    data: nis,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 36),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: _blueLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Scan QR ini saat absensi\natau diperlukan oleh panitia',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _navySoft,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Divider(height: 1, color: _line),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _blueLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.confirmation_number_outlined,
                          color: _blue, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Nomor Peserta',
                              style: TextStyle(fontSize: 12, color: _muted)),
                          const SizedBox(height: 4),
                          Text(
                            nomor.isEmpty ? '-' : nomor,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: _navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
