import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api.dart';
import 'kartu_saya_screen.dart';
import 'ujian_beranda_list.dart';
import 'jadwal_saya_widget.dart';

/// ─────────────────────────────────────────────────────────────
/// Beranda Siswa — Modern CBT Dashboard (rujukan desain user)
/// ─────────────────────────────────────────────────────────────
/// Seluruh data berasal dari DB / RPC (tanpa dummy):
///  • Identitas  : tabel siswa (nama, nis, nomor_peserta, foto_url, kelas)
///  • Jadwal     : RPC jadwal_siswa_aktif
///  • Ujian      : RPC my_ujian_aktif (lewat UjianBerandaList)
/// Field yang NULL di DB (jam/ruang/sesi) sengaja TIDAK ditampilkan.
/// ─────────────────────────────────────────────────────────────

const _bg = Color(0xFFF4F7FF);
const _card = Colors.white;
const _navy = Color(0xFF101F3C);
const _navySoft = Color(0xFF3B4B6B);
const _muted = Color(0xFF8A97B1);
const _blue = Color(0xFF2563EB);
const _blueDeep = Color(0xFF1D4ED8);
const _blueLight = Color(0xFFE8F1FF);
const _green = Color(0xFF22C55E);
const _amber = Color(0xFFF59E0B);
const _orange = Color(0xFFFF9F43);
const _line = Color(0xFFE7EDFA);

class SiswaHomeScreen extends StatefulWidget {
  const SiswaHomeScreen({super.key});

  @override
  State<SiswaHomeScreen> createState() => _SiswaHomeScreenState();
}

class _SiswaHomeScreenState extends State<SiswaHomeScreen> {
  Map<String, dynamic> _dash = {};
  bool _loading = true;
  final _jadwalKey = GlobalKey();
  final _ujianKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = <String, dynamic>{};
    try {
      final res = await Api.fallbackGetApi('/api/siswa/dashboard');
      if (res is Map) stats.addAll(Map<String, dynamic>.from(res));
    } catch (_) {}
    if (stats.isEmpty) {
      final rows = await Api.routerSelect(
        'siswa',
        select: 'nama,nis,nomor_peserta,foto_url,kelas(nama,jurusan(singkatan))',
        eq: {'profile_id': Api.user?.id ?? ''},
      ).catchError((_) => <Map<String, dynamic>>[]);
      if (rows.isNotEmpty) stats.addAll(Map<String, dynamic>.from(rows.first));
    }
    if (!mounted) return;
    setState(() {
      _dash = stats;
      _loading = false;
    });
  }

  void _salin(String n) async {
    await Clipboard.setData(ClipboardData(text: n));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nomor tersalin'),
        backgroundColor: _blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(child: CircularProgressIndicator(color: _blue)),
      );
    }

    final s = _dash;
    final nama = '${s['nama'] ?? 'Siswa'}';
    final nis = '${s['nis'] ?? ''}';
    final nomor = '${s['nomor_peserta'] ?? ''}';
    final foto = '${s['foto_url'] ?? ''}';
    final kelasMap = s['kelas'];
    final kelas = kelasMap is Map ? '${kelasMap['nama'] ?? ''}' : '';
    final jur = kelasMap is Map
        ? '${kelasMap['singkatan'] ?? ''}'
        : '';

    return Scaffold(
      backgroundColor: _bg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(nama: nama, nis: nis, kelas: kelas, jur: jur, foto: foto),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _InfoPeserta(nomor: nomor, onSalin: () => _salin(nomor)),
                  const SizedBox(height: 12),
                  _RingkasanSiswa(stats: s['stats']),
                  const SizedBox(height: 20),
                  _AksesCepat(
                    onJadwal: () => _scrollTo(_jadwalKey),
                    onUjian: () => _scrollTo(_ujianKey),
                    onKartu: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const KartuSayaScreen()),
                    ),
                  ),
                  const SizedBox(height: 20),
                  KeyedSubtree(key: _jadwalKey, child: _JadwalTerdekatCard()),
                  const SizedBox(height: 16),
                  KeyedSubtree(key: _ujianKey, child: const _UjianTersediaCard()),
                  const SizedBox(height: 16),
                  const _PesanCard(),
                ],
              ),
          ),
        ],
      ),
    );
  }
}

/// Kartu profil siswa, nama, chip NIS & kelas.
class _Header extends StatelessWidget {
  final String nama, nis, kelas, jur, foto;
  const _Header({
    required this.nama,
    required this.nis,
    required this.kelas,
    required this.jur,
    required this.foto,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: _SoftCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                    color: _blueLight, shape: BoxShape.circle),
                child: CircleAvatar(
                  radius: 34,
                  backgroundColor: _blueLight,
                  backgroundImage: foto.isNotEmpty ? NetworkImage(foto) : null,
                  child: foto.isEmpty
                      ? const Icon(Icons.person_rounded, size: 34, color: _blue)
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nama,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: _navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: [
                        if (nis.isNotEmpty) _chip('NIS $nis'),
                        if (kelas.isNotEmpty)
                          _chip(jur.isNotEmpty ? '$kelas • $jur' : kelas),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _blueLight,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: _line),
        ),
        child: Text(
          t,
          style: const TextStyle(
              fontSize: 11, color: _blue, fontWeight: FontWeight.w600),
        ),
      );
}

/// wrapper kartu putih neumorphic.
class _SoftCard extends StatelessWidget {
  final Widget child;
  const _SoftCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.07),
            blurRadius: 24,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoPeserta extends StatelessWidget {
  final String nomor;
  final VoidCallback onSalin;
  const _InfoPeserta({required this.nomor, required this.onSalin});

  @override
  Widget build(BuildContext context) {
    return _SoftCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _blueLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.person_rounded, color: _blue, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informasi Peserta',
                    style: TextStyle(fontSize: 13, color: _muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nomor.isEmpty ? '-' : nomor,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: nomor.isEmpty ? null : onSalin,
              tooltip: 'Salin nomor',
              icon: const Icon(Icons.copy_all_rounded, color: _blue, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingkasanSiswa extends StatelessWidget {
  final dynamic stats;
  const _RingkasanSiswa({this.stats});

  @override
  Widget build(BuildContext context) {
    final m = stats is Map ? Map<String, dynamic>.from(stats) : <String, dynamic>{};
    final nilai = m['rata_nilai'];
    final nilaiTeks = nilai == null
        ? '-'
        : (nilai is num ? nilai.toStringAsFixed(1) : '$nilai');
    return Row(
      children: [
        _stat('Total ujian', '${m['total_ujian'] ?? 0}', _blue),
        const SizedBox(width: 8),
        _stat('Selesai', '${m['ujian_selesai'] ?? 0}', _green),
        const SizedBox(width: 8),
        _stat('Rata nilai', nilaiTeks, _orange),
      ],
    );
  }

  Widget _stat(String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A8A).withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 3),
              Text(label,
                  style: const TextStyle(fontSize: 10.5, color: _muted)),
            ],
          ),
        ),
      );
}

class _AksesCepat extends StatelessWidget {
  final VoidCallback onJadwal, onUjian, onKartu;
  const _AksesCepat({
    required this.onJadwal,
    required this.onUjian,
    required this.onKartu,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.bolt_rounded, color: _amber, size: 20),
            SizedBox(width: 8),
            Text(
              'Akses Cepat',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _navy),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _shortcut(Icons.calendar_month_rounded, 'Jadwal Ujian',
                  _blue, onJadwal),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _shortcut(Icons.description_rounded, 'Ujian Tersedia',
                  _green, onUjian),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _shortcut(Icons.qr_code_2_rounded, 'Kartu & QR',
                  _orange, onKartu),
            ),
          ],
        ),
      ],
    );
  }

  Widget _shortcut(IconData icon, String label, Color color, VoidCallback onTap) {
    return _SoftCard(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 9),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _navySoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JadwalTerdekatCard extends StatefulWidget {
  @override
  State<_JadwalTerdekatCard> createState() => _JadwalTerdekatCardState();
}

class _JadwalTerdekatCardState extends State<_JadwalTerdekatCard> {
  List<dynamic> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await Api.routerRpc('jadwal_siswa_aktif');
      setState(() {
        _rows = raw is List ? raw : const [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final j = _rows.isNotEmpty ? _rows.first : null;
    final mapel = j is Map ? '${j['mapel'] ?? ''}' : '';
    final tanggal = j is Map ? '${j['tanggal'] ?? ''}' : '';
    final jamMulai = j is Map ? '${j['jam_mulai'] ?? ''}' : '';
    final jamSelesai = j is Map ? '${j['jam_selesai'] ?? ''}' : '';
    final ruang = j is Map ? '${j['ruang_nama'] ?? ''}' : '';
    final jam = (jamMulai.isNotEmpty && jamSelesai.isNotEmpty &&
            jamMulai != 'null' && jamSelesai != 'null')
        ? '$jamMulai – $jamSelesai'
        : '';

    return _SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Row(
              children: const [
                Icon(Icons.calendar_month_rounded, color: _blue, size: 20),
                SizedBox(width: 9),
                Text(
                  'Jadwal Ujian Terdekat',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: _navy),
                ),
              ],
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(color: _blue)),
            )
          else if (j == null)
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 4, 18, 18),
              child: Text('Belum ada jadwal ujian untuk kelasmu.',
                  style: TextStyle(fontSize: 13, color: _muted)),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
              child: Row(
                children: [
                  _tanggalBadge(tanggal),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mapel.isEmpty ? 'Ujian' : mapel,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _navy),
                        ),
                        const SizedBox(height: 6),
                        if (jam.isNotEmpty)
                          _meta(Icons.schedule_rounded, jam),
                        if (ruang.isNotEmpty && ruang != 'null')
                          _meta(Icons.meeting_room_outlined, ruang),
                        if (jam.isEmpty && (ruang.isEmpty || ruang == 'null'))
                          _meta(Icons.event_rounded, tanggal),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tanggalBadge(String tanggal) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(tanggal);
    final hari = m != null ? m.group(3)! : '--';
    const bulan = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final bl = m != null ? int.tryParse(m.group(2)!) ?? 0 : 0;
    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: _blueLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(hari,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: _blue)),
          Text(bl > 0 && bl < bulan.length ? bulan[bl] : '',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: _navySoft)),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Icon(icon, size: 14, color: _muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 12, color: _navySoft)),
            ),
          ],
        ),
      );
}

class _UjianTersediaCard extends StatelessWidget {
  const _UjianTersediaCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: const [
              Icon(Icons.rocket_launch_rounded, color: _blue, size: 20),
              SizedBox(width: 8),
              Text(
                'Ujian Tersedia',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _navy),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const UjianBerandaList(),
      ],
    );
  }
}

class _PesanCard extends StatelessWidget {
  const _PesanCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_blue, Color(0xFF60A5FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -20,
            child: Opacity(
              opacity: 0.25,
              child: Icon(Icons.emoji_events_rounded,
                  size: 120, color: Colors.white.withValues(alpha: 0.9)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 80, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Selamat mengerjakan,\nSemoga sukses!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
