import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../core/design.dart';
import '../../core/soal_preview.dart';
import '../../services/api.dart';
import '../../services/kiosk.dart';
import '../../services/jawaban_store.dart';

class PelaksanaanScreen extends StatefulWidget {
  final Map<String, dynamic> ujian;
  final String pesertaId;
  const PelaksanaanScreen({super.key, required this.ujian, required this.pesertaId});
  @override
  State<PelaksanaanScreen> createState() => _PelaksanaanScreenState();
}

class _PelaksanaanScreenState extends State<PelaksanaanScreen> with WidgetsBindingObserver {
  // Batas pelanggaran baru menyebabkan auto-submit. Dulu 3 -> terlalu kecil:
  // satu kejadian sistem (notif shade/dialog) bisa berulang sampai auto-submit.
  final int _penaltyLimit = 5;
  // Durasi minimal di luar aplikasi sebelum dianggap sengaja keluar.
  // Di bawah ini = kejadian sistem yang wajar, bukan pelanggaran.
  static const Duration _minAwayDuration = Duration(seconds: 5);
  late int _durasiDetik;
  Timer? _timer;
  int _sisaDetik = 0;
  List<Map<String, dynamic>> _soal = [];
  Map<String, String?> _jawaban = {};
  Map<String, bool> _ragu = {};
  int _idx = 0;
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  int _juangPaused = 0;
  bool _kiosk = false;
  bool _showPalette = false;
  // waktu keluar dari aplikasi (untuk membedakan kejadian sesaat vs sengaja)
  DateTime? _keluarPada;
  // satu pelanggaran per siklus keluar-masuk (jangan dobel hitung)
  bool _sudahDihitungSiklusIni = false;
  DateTime? _terakhirPelanggaran;

  // ===== LOCAL STORAGE + FLUSH BERKALA (anti rate-limit & anti-hilang) =====
  late final JawabanStore _store = JawabanStore(widget.pesertaId);
  final Set<String> _belumKirim = {}; // soalId yang berubah & belum disinkron ke server
  Timer? _flushTimer;
  // controller essay per-soal (JANGAN bikin baru tiap build -> bikin cursor ngaco)
  final Map<String, TextEditingController> _essayCtrl = {};

  TextEditingController _ctrlFor(String soalId) {
    return _essayCtrl.putIfAbsent(soalId, () {
      final c = TextEditingController(text: _jawaban[soalId] ?? '');
      c.selection = TextSelection.collapsed(offset: c.text.length);
      return c;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    final menit = (widget.ujian['alokasi_menit'] as num?)?.toInt() ?? 90;
    _durasiDetik = menit * 60;
    _sisaDetik = _durasiDetik;
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _flushTimer?.cancel();
    for (final c in _essayCtrl.values) { c.dispose(); }
    Kiosk.alarmStop();
    Kiosk.setSecure(false);
    Kiosk.exitKiosk();
    Kiosk.detachIntrusion();
    Kiosk.stopVolumeEnforcer();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await Api.routerRpc('soal_milik_ujian', params: {'p_peserta': widget.pesertaId});
      final data = Map<String, dynamic>.from(res as Map);
      _soal = List<Map<String, dynamic>>.from(data['soal'] as List? ?? []);
      final jw = data['jawaban'];
      if (jw is Map) {
        for (final e in jw.entries) {
          final m = e.value;
          if (m is Map) {
            _jawaban['${e.key}'] = (m['jawaban'] ?? '').toString();
            _ragu['${e.key}'] = m['ragu'] == true;
          }
        }
      }
      final sisa = data['sisa_detik'];
      if (sisa is num && sisa > 0) _sisaDetik = sisa.toInt();
      final pStatus = data['status_peserta']?.toString();
      // ===== JAM AKSES: cek apakah ujian sudah di waktu-nya =====
      // server RPC soal_milik_ujian sudah filter ujian yang JAM AKSES-nya belum buka
      // (via my_ujian_aktif → hanya kembalikan ujian yang waktu_mulai <= now <= waktu_selesai)
      // Jadi kalau siswa sudah masuk sini, artinya JAM AKSES-nya sudah terbuka.
      // TAPI, timer countdown yang ditampilkan harus pakai sisa_detik dari server
      // (bukan alokasi_menit dari client), karena server tahu kapan ujian harus selesai.
      // ===== RESUME: kalau sudah submit sebelumnya, langsung ke hasil =====
      if (pStatus == 'selesai' && _soal.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _kiosk = true;
          _loading = false;
        });
        Kiosk.exitKiosk();
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => _SelesaiScreen(title: 'Ujian sudah selesai', rekap: {}),
        ));
        return;
      }
      // ===== RESUME dari LOCAL: kalau HP sempat mati, ambil jawaban tersimpan di HP =====
      try {
        final lokal = await _store.loadAll();
        for (final e in lokal.entries) {
          final soId = e.key;
          final v = e.value;
          // pakai lokal kalau ada isi, atau server kosong
          if ((v['jawaban'] ?? '').toString().isNotEmpty ||
              (_jawaban[soId] ?? '').isEmpty) {
            _jawaban[soId] = (v['jawaban'] ?? '').toString();
            _ragu[soId] = v['ragu'] == true;
          }
        }
        // jawaban lokal yang belum ada di server -> tandai perlu dikirim
        final synced = await _store.getSynced();
        for (final e in lokal.entries) {
          if (!synced.contains(e.key)) _belumKirim.add(e.key);
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _kiosk = true;
        _loading = false;
      });
      Kiosk.setSecure(true);
      Kiosk.enterKiosk();
      Kiosk.onEvents(onIntrusionCb: _onIntrusion, onPinningCb: _onPinningWarning);
      _startTimer();
      _startFlush(); // flush berkala tiap 2 menit (bukan tiap tap)
      _cekDeviceOwner();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat ujian: $e';
        _loading = false;
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _sisaDetik--);
      if (_sisaDetik <= 0) {
        t.cancel();
        _submit(auto: true);
      }
    });
  }

  bool _isOwner = false;
  void _cekDeviceOwner() async {
    final ok = await Kiosk.isDeviceOwner();
    if (mounted) setState(() => _isOwner = ok);
  }

  void _onIntrusion() {
    if (!_kiosk || !mounted || _showPalette || _submitting) return;
    // Native sudah menyaring fokus hilang < 2.5 detik (notif shade, dialog,
    // keyboard, immersive flicker) -> event ini = intrusi sungguhan.
    _hitungPelanggaran('tab_switch');
  }

  void _onPinningWarning() {
    // UI "pinning" dihapus:HWARN hanya berupa teks, bukan Fundamental
    // (penyebabnya tetap di-log native). Tidak ada yang perlu ditampilkan ke siswa.
  }

  void _snackIntrusi([String jenis = 'tab_switch']) {
    final keluarApp = jenis == 'keluar_app';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(keluarApp ? Icons.exit_to_app : Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                keluarApp
                    ? 'App sempat tertutup. Kembali ke ujian ya.'
                    : 'Terdeteksi jendela/overlay lain! Alarm aktif — kembali fokus ke ujian.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: keluarApp ? AppTheme.accent : AppTheme.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // CATATAN PENTING:
    // - 'inactive' fired untuk kejadian wajar (notif shade, dialog sistem,
    //   keyboard, layar mati sebentar) -> TIDAK dihitung sebagai pelanggaran.
    // - hanya 'paused'/'hidden' (app benar-benar di belakang/lock) yang dicatat,
    //   dan hanya bila berlangsung > _minAwayDuration.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (_kiosk) {
        _sudahDihitungSiklusIni = false;
        _keluarPada = DateTime.now();
        if (_sisaDetik > 0) Kiosk.alarmStart(maxVolume: true);
      }
    } else if (state == AppLifecycleState.resumed) {
      Kiosk.alarmStop();
      if (_kiosk) _evaluasiKeluar();
    }
  }

  /// Dipanggil saat app kembali ke depan: catat pelanggaran hanya kalau
  /// waktu di luar aplikasi cukup lama (bukan sentuhan sesaat ke notif shade).
  void _evaluasiKeluar() {
    final keluarPada = _keluarPada;
    _keluarPada = null;
    if (keluarPada == null || _sudahDihitungSiklusIni) return;
    final durasi = DateTime.now().difference(keluarPada);
    if (durasi < _minAwayDuration) return; // kejadian sesaat -> jangan dihitung
    _sudahDihitungSiklusIni = true;
    _hitungPelanggaran('keluar_app');
  }
  void _hitungPelanggaran(String jenis) {
    if (!_kiosk || !mounted) return;
    final now = DateTime.now();
    if (_terakhirPelanggaran != null &&
        now.difference(_terakhirPelanggaran!) < const Duration(seconds: 10)) {
      return;
    }
    _terakhirPelanggaran = now;
    _juangPaused++;
    _catatPelanggaran(jenis);
    setState(() {});
    _snackIntrusi();
    if (_juangPaused > _penaltyLimit) _submit(auto: true);
  }

  Future<void> _catatPelanggaran([String jenis = 'tab_switch']) async {
    try {
      await Api.routerRpc('catat_pelanggaran', params: {
        'p_peserta': widget.pesertaId,
        'p_jenis': jenis,
      });
    } catch (_) {}
  }

  // ===== SIMPAN LOKAL (instan, gak ada internet) =====
  Future<void> _simpanLokal() async {
    await _store.saveAll(_jawaban, _ragu);
  }

  /// Dipanggil tiap murid tap jawaban: SIMPAN LOKAL SAJA (gak kirim server).
  Future<void> _saveJawaban(String soalId, {bool flush = false, String? value}) async {
    if (value != null) _jawaban[soalId] = value;
    _belumKirim.add(soalId);
    await _simpanLokal();
    // flush=true hanya dipakai saat submit (paksa kirim)
    if (flush) await _flushKeServer();
  }

  /// Kirim jawaban yang BELUM tersinkron ke server (batch, hemat request).
  Future<void> _flushKeServer() async {
    if (_belumKirim.isEmpty) return;
    final ids = _belumKirim.toList();
    for (final id in ids) {
      try {
        await Api.routerRpc('simpan_jawaban', params: {
          'p_peserta': widget.pesertaId,
          'p_soal': id,
          'p_jawaban': _jawaban[id] ?? '',
          'p_ragu': _ragu[id] ?? false,
        });
        _belumKirim.remove(id);
      } catch (_) {
        // gagal -> biarkan di antrian, dicoba flush berikutnya
      }
      await Future.delayed(const Duration(milliseconds: 60)); // jeda kecil antar-request
    }
    try {
      final synced = await _store.getSynced();
      synced.addAll(ids.where((i) => !_belumKirim.contains(i)));
      await _store.markSynced(synced);
    } catch (_) {}
  }

  /// Flush otomatis tiap 2 menit (ringan, gak rate-limit).
  void _startFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(const Duration(minutes: 2), (_) async {
      if (_belumKirim.isNotEmpty) await _flushKeServer();
    });
  }

  Future<void> _submit({bool auto = false}) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    _timer?.cancel();
    Kiosk.alarmStop();
    // 1) pastikan SEMUA jawaban kekirim (retry sampai _belumKirim kosong)
    for (int attempt = 0; attempt < 6; attempt++) {
      await _flushKeServer();
      if (_belumKirim.isEmpty) break;
      await Future.delayed(const Duration(seconds: 2));
    }
    // 2) kumpulkan dengan retry (jangan keluar sebelum server konfirmasi)
    bool okKumpul = false;
    for (int attempt = 0; attempt < 5; attempt++) {
      try {
        await Api.routerRpc('kumpulkan_ujian', params: {'p_peserta': widget.pesertaId});
        okKumpul = true;
        break;
      } catch (e) {
        final s = e.toString();
        // "sudah dikumpulkan" = sebenarnya sukses (idempoten)
        if (s.contains('sudah dikumpulkan') || s.contains('Tidak sedang')) { okKumpul = true; break; }
        if (attempt < 4) await Future.delayed(Duration(seconds: 2 + attempt * 2));
      }
    }
    if (okKumpul) {
      // Server mengkonfirmasi -> hapus cache lokal HP (anti duplikat, privasi)
      try { _store.clear(); } catch (_) {}
      _belumKirim.clear();
    }
    if (!okKumpul) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Jaringan bermasalah — jawaban TERSIMPAN di server. Tap "Kumpulkan" lagi saat sinyal pulih.'),
            backgroundColor: AppTheme.danger, duration: Duration(seconds: 8)),
      );
      return;
    }
    Map<String, dynamic> rekap = {};
    try {
      final ans = await Api.routerSelect('jawaban_siswa',
          select: 'soal_id,ragu_ragu',
          eq: {'peserta_ujian_id': widget.pesertaId});
      rekap = {
        'jawab': ans.length,
        'ragu': ans.where((a) => a['ragu_ragu'] == true).length,
      };
    } catch (_) {}
    _flushTimer?.cancel();
    if (!mounted) return;
    _gotoResults(auto ? 'Waktu habis' : 'Ujian selesai', rekap);
  }

  void _gotoResults(String title, Map<String, dynamic> rekap) {
    try { _store.clear(); } catch (_) {}
    _kiosk = false;
    Kiosk.exitKiosk();
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => _SelesaiScreen(title: title, rekap: rekap),
    ));
  }

  String _fmt(int d) {
    final mm = (d ~/ 60).toString().padLeft(2, '0');
    final ss = (d % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _buildLoading();
    if (_error != null) return _buildError();
    if (_soal.isEmpty) {
      return const Scaffold(
        backgroundColor: Cbt.paper,
        body: CbtEmpty('Ujian belum punya soal', 'Hubungi guru kalau ini bukan seharusnya.'),
      );
    }

    final current = _soal[_idx];
    final curId = current['id'].toString();
    final jenis = current['jenis']?.toString() ?? 'pg';
    final opsiRaw = current['opsi'];
    final opsiList = opsiRaw is List ? opsiRaw : <dynamic>[];
    final answered = _jawaban.values.where((v) => v != null && v!.isNotEmpty).length;
    final flagged = _ragu.values.where((v) => v == true).length;
    final low = _sisaDetik < 300;
    final critical = _sisaDetik < 60;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _hitungPelanggaran('keluar_app');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.block, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Expanded(child: Text('Tombol kembali diblokir selama ujian', style: TextStyle(fontWeight: FontWeight.w600))),
            ]),
            backgroundColor: Cbt.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Scaffold(
        backgroundColor: Cbt.paper,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(low, critical),
                  _buildProgress(answered, flagged),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 108),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSoalCard(current, curId, jenis, opsiList),
                          const SizedBox(height: 14),
                          _buildRaguChip(curId),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: _buildBottomBar(answered, flagged),
              ),
              if (_showPalette) ...[
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _showPalette = false),
                    child: Container(color: Cbt.ink.withValues(alpha: 0.48)),
                  ),
                ),
                Positioned(left: 0, right: 0, bottom: 0, child: _buildLembarJawaban()),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Kondisi awal ──────────────────────────────────────────────
  Widget _buildLoading() => const Scaffold(
        backgroundColor: Cbt.paper,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 46, height: 46,
                child: CircularProgressIndicator(color: Cbt.blue, strokeWidth: 3),
              ),
              SizedBox(height: 20),
              Text('Menyiapkan ujian', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Cbt.ink)),
              SizedBox(height: 6),
              Text('Lingkungan terkunci • pengawas aktif', style: Cbt.caption),
            ],
          ),
        ),
      );

  Widget _buildError() => Scaffold(
        backgroundColor: Cbt.paper,
        appBar: AppBar(title: const Text('Ujian'), backgroundColor: Cbt.ink),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 56, color: Cbt.red),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Cbt.ink)),
                const SizedBox(height: 24),
                Cbt.button(text: 'Kembali', icon: Icons.arrow_back, onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
        ),
      );

  // ── Header: judul + jam (elemen paling penting) ──────────────
  Widget _buildHeader(bool low, bool critical) {
    final jam = _formatJam(_sisaDetik);
    final warnaJam = critical ? Cbt.red : (low ? Cbt.amber : Colors.white);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: const BoxDecoration(
        color: Cbt.ink,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (widget.ujian['mapel'] ?? 'Ujian').toString(),
                      style: const TextStyle(color: Color(0xFF9FB6CC), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      (widget.ujian['nama'] ?? 'Ujian').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('WAKTU TERSISA', style: TextStyle(color: Color(0xFF9FB6CC), fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.3)),
                  const SizedBox(height: 2),
                  Text(jam, style: Cbt.display.copyWith(fontSize: 30, color: warnaJam)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatJam(int detik) {
    final d = detik < 0 ? 0 : detik;
    final h = d ~/ 3600;
    final m = (d % 3600) ~/ 60;
    final s = d % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildProgress(int answered, int flagged) {
    final p = (_idx + 1) / _soal.length;
    return Container(
      color: Cbt.paper,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Column(
        children: [
          Row(
            children: [
              Text('SOAL ${_idx + 1} / ${_soal.length}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: Cbt.ink)),
              const Spacer(),
              _legend(Cbt.teal, '$answered terjawab'),
              const SizedBox(width: 10),
              _legend(Cbt.amber, '$flagged ragu'),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: p,
              minHeight: 5,
              backgroundColor: Cbt.line,
              valueColor: AlwaysStoppedAnimation(Cbt.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: Cbt.caption),
        ],
      );

  // ── Kartu soal: menyerupai kertas dengan pinggiran biru ──────
  Widget _buildSoalCard(Map<String, dynamic> soal, String curId, String jenis, List opsiList) {
    final isJodoh = SoalJodoh.isJodoh(jenis);
    final teks = isJodoh
        ? SoalJodoh.instruksi
        : (soal['soal'] ?? '').toString();
    final opsiRaw = soal['opsi'];
    final gambar = soal['gambar_url']?.toString();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Cbt.line),
        boxShadow: [BoxShadow(color: Cbt.ink.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 4,
            color: Cbt.blue,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Cbt.label('PERTANYAAN ${_idx + 1}'),
                const SizedBox(height: 10),
                Text(teks, style: Cbt.question),
                if (gambar != null && gambar.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(gambar, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  ),
                ],
                const SizedBox(height: 20),
                _buildJawaban(curId, jenis, opsiList, opsiRaw),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJawaban(String curId, String jenis, List opsiList, dynamic opsiRaw) {
    if (jenis == 'jodoh' || jenis == 'menjodohkan') {
      return _buildJodoh(curId, opsiRaw);
    }
    if (jenis == 'essay') {
      final c = _ctrlFor(curId);
      return TextField(
        controller: c,
        onChanged: (v) => _saveJawaban(curId),
        maxLines: jenis == 'essay' ? 6 : 4,
        style: Cbt.option,
        decoration: InputDecoration(
          hintText: jenis == 'essay'
              ? 'Tulis jawabanmu di sini…'
              : 'Tulis pasangan jawaban (mis. 1-B, 2-A, 3-C)…',
          hintStyle: const TextStyle(color: Cbt.muted),
          filled: true,
          fillColor: Cbt.paper,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Cbt.line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Cbt.line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Cbt.blue, width: 1.5)),
        ),
      );
    }
    const huruf = ['A', 'B', 'C', 'D', 'E', 'F'];
    return Column(
      children: List.generate(opsiList.length, (i) {
        final raw = opsiList[i];
        final teks = raw is Map
            ? (raw['teks'] ?? raw['opsi'] ?? raw['label'] ?? '').toString()
            : raw.toString();
        final pilih = (_jawaban[curId] ?? '') == huruf[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildOpsi(i, huruf[i], teks, pilih, curId),
        );
      }),
    );
  }

  /// Hash string stabil (di semua process) utk seed acak pilihan jodoh.
  int _stableHash(String s) {
    int h = 0;
    for (final c in s.codeUnits) {
      h = ((h << 5) - h + c) & 0xFFFFFFFF;
    }
    return h;
  }

  /// Soal menjodohkan: tiap item kiri dipasangkan ke salah satu pilihan kanan.
  /// Jawaban disimpan sebagai JSON peta {"0":"1", ...} (index kiri -> index kanan
  /// ASLI di data soal), sesuai format yang dicek di server (kunci.map).
  /// Kolom kanan DIOCAK tampilnya (deterministik per soal — seed dari id soal)
  /// supaya murid ga bisa nebak pola 1-A 2-B 3-C. Yang disimpan tetap index asli.
  Widget _buildJodoh(String curId, dynamic opsiRaw) {
    List<dynamic> kiri = const [];
    List<dynamic> kanan = const [];
    if (opsiRaw is Map) {
      kiri = opsiRaw['kiri'] is List ? opsiRaw['kiri'] : const [];
      kanan = opsiRaw['kanan'] is List ? opsiRaw['kanan'] : const [];
    }
    if (kiri.isEmpty || kanan.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Cbt.amber.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: const Text('Data pasangan soal belum tersedia. Hubungi guru.', style: Cbt.caption),
      );
    }

    // Acak urutan tampil kolom kanan: seed STABIL dari id soal + id peserta.
    // - Kiri tetap urut 1,2,3 (sesuai keinginan: "kiri 1 = jawaban/pasangan").
    // - Kanan diacak -> pasangan kiri 1 bisa muncul di posisi A/D/E/F/G.
    // - Seed dipakai ./peserta biar tiap siswa dapat urutan beda (anti nyontek
    //   teman sebelah), tapi konsisten untuk siswa yg sama (ga nge-reset pas
    //   pindah soal / hot reload).
    // Pakai hash manual (bukan String.hashCode) karena hashCode Dart bisa
    // beda antar process -> urutan bakal loncat-loncat pas rebuild.
    final seed = _stableHash('$curId|${widget.pesertaId}');
    final urutan = List<int>.generate(kanan.length, (i) => i);
    urutan.shuffle(Random(seed));

    Map<String, dynamic> pilihan = {};
    final mentah = _jawaban[curId] ?? '';
    try {
      final d = jsonDecode(mentah);
      if (d is Map) pilihan = Map<String, dynamic>.from(d);
    } catch (_) {}

    final terisi = pilihan.values.where((v) => v != null && v.toString().isNotEmpty).length;
    final lengkap = terisi == kiri.length;
    final tinggiMaks = (MediaQuery.sizeOf(context).height * 0.52).clamp(240.0, 520.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Cbt.label('PILIH PASANGAN YANG TEPAT'),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: lengkap
                    ? Cbt.teal.withValues(alpha: 0.14)
                    : Cbt.blue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '$terisi / ${kiri.length} terisi',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: lengkap ? Cbt.teal : Cbt.blue,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          SoalJodoh.instruksi,
          style: Cbt.caption,
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: tinggiMaks.toDouble()),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.all(10),
            itemCount: kiri.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, i) {
              final tersimpan = pilihan['$i']?.toString();
              final posisiTampil = tersimpan == null
                  ? null
                  : urutan.indexOf(int.tryParse(tersimpan) ?? -1);
              final sudah = posisiTampil != null && posisiTampil >= 0;
              final field = DropdownButtonFormField<String>(
                initialValue: sudah ? '$posisiTampil' : null,
                isDense: false,
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Pilih pasangan…',
                  hintStyle: const TextStyle(fontSize: 13, color: Cbt.muted),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: const BorderSide(color: Cbt.line)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: const BorderSide(color: Cbt.line)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: const BorderSide(color: Cbt.blue, width: 1.8)),
                ),
                items: [
                  for (var j = 0; j < urutan.length; j++)
                    DropdownMenuItem<String>(
                      value: '$j',
                      child: Text(
                        '${String.fromCharCode(65 + j)}. ${kanan[urutan[j]]}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, color: Cbt.ink),
                      ),
                    ),
                ],
                onChanged: (v) {
                  setState(() {
                    if (v == null) {
                      pilihan.remove('$i');
                    } else {
                      pilihan['$i'] = urutan[int.parse(v)].toString();
                    }
                  });
                  _saveJawaban(curId, value: jsonEncode(pilihan));
                },
              );
              final nomor = Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: sudah
                      ? Cbt.teal.withValues(alpha: 0.14)
                      : Cbt.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${i + 1}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: sudah ? Cbt.teal : Cbt.blue)),
              );
              final teks = Expanded(
                child: Text(
                  kiri[i].toString(),
                  style: const TextStyle(
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      color: Cbt.ink),
                ),
              );
              final centang = Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: sudah ? Cbt.teal : Colors.transparent,
              );
              return LayoutBuilder(
                builder: (context, box) {
                  final sempit = box.maxWidth < 430;
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: sudah
                          ? Cbt.teal.withValues(alpha: 0.05)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sudah
                            ? Cbt.teal.withValues(alpha: 0.35)
                            : Cbt.line,
                      ),
                    ),
                    child: sempit
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(children: [nomor, const SizedBox(width: 10), teks, centang]),
                              const SizedBox(height: 8),
                              field,
                            ],
                          )
                        : Row(
                            children: [
                              nomor,
                              const SizedBox(width: 10),
                              teks,
                              centang,
                              const SizedBox(width: 12),
                              SizedBox(width: 190, child: field),
                            ],
                          ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOpsi(int index, String huruf, String teks, bool pilih, String curId) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      decoration: BoxDecoration(
        color: pilih ? Cbt.blue.withValues(alpha: 0.08) : Cbt.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pilih ? Cbt.blue : Cbt.line, width: pilih ? 1.6 : 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _saveJawaban(curId, value: huruf),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 30, height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: pilih ? Cbt.blue : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: pilih ? Cbt.blue : Cbt.line),
                  ),
                  child: Text(huruf, style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: pilih ? Colors.white : Cbt.inkSoft,
                  )),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(teks, style: Cbt.option)),
                if (_ragu[curId] == true)
                  const Icon(Icons.flag_rounded, size: 16, color: Cbt.amber),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRaguChip(String curId) {
    final ragu = _ragu[curId] == true;
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _ragu[curId] = !ragu);
            _saveJawaban(curId);
          },
          borderRadius: BorderRadius.circular(99),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: ragu ? Cbt.amber.withValues(alpha: 0.16) : Colors.white,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: ragu ? Cbt.amber : Cbt.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.flag_rounded, size: 16, color: ragu ? Cbt.amber : Cbt.muted),
                const SizedBox(width: 7),
                Text(ragu ? 'Ditandai ragu' : 'Tandai ragu',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: ragu ? Cbt.amber : Cbt.inkSoft)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Bilah bawah: navigasi + lembar jawaban ───────────────────
  Widget _buildBottomBar(int answered, int flagged) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Cbt.line)),
        boxShadow: [BoxShadow(color: Cbt.ink.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            SizedBox(
              width: 104,
              child: OutlinedButton.icon(
                onPressed: _idx == 0
                    ? null
                    : () {
                        FocusScope.of(context).unfocus();
                        setState(() => _idx--);
                      },
                icon: const Icon(Icons.arrow_back_ios_new, size: 14),
                label: const Text('Sebelum', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Cbt.ink,
                  side: const BorderSide(color: Cbt.line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Material(
                color: Cbt.paper,
                borderRadius: BorderRadius.circular(11),
                child: InkWell(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    setState(() => _showPalette = true);
                  },
                  borderRadius: BorderRadius.circular(11),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Cbt.line),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.grid_view_rounded, size: 16, color: Cbt.blue),
                        const SizedBox(width: 6),
                        Text('LJK ${_idx + 1}/${_soal.length}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Cbt.ink)),
                        const SizedBox(width: 6),
                        Text('• $answered✓ ${flagged > 0 ? '$flagged⚑' : ''}',
                            style: const TextStyle(fontSize: 11, color: Cbt.muted)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 104,
              child: _idx == _soal.length - 1
                  ? FilledButton.icon(
                      onPressed: _submitting ? null : _confirmSubmit,
                      icon: const Icon(Icons.done_all, size: 16),
                      label: const Text('Selesai', style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        backgroundColor: Cbt.teal,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        setState(() => _idx++);
                      },
                      icon: const Icon(Icons.arrow_forward_ios, size: 14),
                      label: const Text('Berikut', style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        backgroundColor: Cbt.blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Lembar jawaban (palette) ──────────────────────────────────
  Widget _buildLembarJawaban() {
    const answeredColor = Cbt.teal;
    const raguColor = Cbt.amber;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.72),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(22), topRight: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.grid_view_rounded, size: 20, color: Cbt.blue),
                const SizedBox(width: 8),
                const Text('Lembar Jawaban',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Cbt.ink)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() => _showPalette = false),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _legend(Cbt.teal, 'Terjawab'),
                const SizedBox(width: 12),
                _legend(Cbt.amber, 'Ragu'),
                const SizedBox(width: 12),
                _legend(Cbt.line, 'Kosong'),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 9,
                  crossAxisSpacing: 9,
                  childAspectRatio: 1,
                ),
                itemCount: _soal.length,
                itemBuilder: (context, i) {
                  final s = _soal[i];
                  final id = s['id'].toString();
                  final isi = (_jawaban[id] ?? '').isNotEmpty;
                  final ragu = _ragu[id] == true;
                  final aktif = i == _idx;
                  final warna = ragu ? raguColor : (isi ? answeredColor : Cbt.line);
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        setState(() {
                          _idx = i;
                          _showPalette = false;
                        });
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isi || ragu ? warna.withValues(alpha: 0.14) : Cbt.paper,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: aktif ? Cbt.blue : warna,
                            width: aktif ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: aktif ? Cbt.blue : Cbt.ink,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Cbt.button(
              text: 'Kumpulkan Ujian',
              icon: Icons.send_rounded,
              color: Cbt.teal,
              expanded: true,
              onPressed: _submitting ? null : _confirmSubmit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSubmit() async {
    FocusScope.of(context).unfocus();
    final belum = _soal.length - _jawaban.values.where((v) => v != null && v.isNotEmpty).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: Cbt.teal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.assignment_turned_in_rounded, color: Cbt.teal),
            ),
            const SizedBox(width: 12),
            const Text('Kumpulkan ujian?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Cbt.ink)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              belum > 0 ? 'Masih ada $belum soal yang belum dijawab.' : 'Semua soal sudah terjawab.',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Cbt.ink),
            ),
            const SizedBox(height: 6),
            Text(
              belum > 0
                  ? 'Soal kosong akan dinilai salah. Pastikan kamu sudah memilih dengan benar.'
                  : 'Cek lagi jawaban yang ditandai ragu sebelum mengumpulkan.',
              style: Cbt.caption,
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Periksa lagi', style: TextStyle(color: Cbt.inkSoft)),
          ),
          Cbt.button(text: 'Ya, kumpulkan', color: Cbt.teal, onPressed: () => Navigator.pop(c, true)),
        ],
      ),
    );
    if (ok == true) await _submit();
  }
}

/// Empty state ringan untuk daftar kosong.
class CbtEmpty extends StatelessWidget {
  final String title;
  final String? subtitle;
  const CbtEmpty(this.title, [this.subtitle]);

  @override
  Widget build(BuildContext context) => Cbt.empty(icon: Icons.inbox_rounded, title: title, subtitle: subtitle);
}

class _SelesaiScreen extends StatelessWidget {
  final String title;
  final Map<String, dynamic> rekap;
  const _SelesaiScreen({required this.title, this.rekap = const {}});
  @override
  Widget build(BuildContext context) {
    final isTimeout = title == 'Waktu habis';
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: (isTimeout ? AppTheme.danger : AppTheme.secondary).withValues(alpha: 0.12), shape: BoxShape.circle),
                child: Icon(isTimeout ? Icons.timer_off_rounded : Icons.check_circle_rounded, size: 64, color: isTimeout ? AppTheme.danger : AppTheme.secondary),
              ),
              const SizedBox(height: 24),
              Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),
              Text(isTimeout ? 'Waktu ujian telah berakhir dan jawaban otomatis terkumpul.' : 'Jawaban berhasil dikumpulkan!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 14, height: 1.5)),
              const SizedBox(height: 8),
                Text((rekap['jawab'] ?? 0) > 0
                    ? 'Tersimpan di server: ${rekap['jawab']} butir${(rekap['ragu'] ?? 0) > 0 ? ' • ${rekap['ragu']} ditandai ragu' : ''}'
                    : 'Jawaban Anda telah terkirim ke server.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF059669), fontSize: 12)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Kembali ke Beranda'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
