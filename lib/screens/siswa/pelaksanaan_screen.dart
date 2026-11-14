import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
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
  final int _penaltyLimit = 3;
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

  // ===== JODOH 2 KOLOM =====
  // - Baris kiri: soal (1..N). Baris kanan: jawaban acak (a..N, DIACAK 1× per load).
  // - Di bawahnya: input jawaban per soal (siswa ketik huruf a,b,c... atau nomor 1,2,3...).
  // - Jawaban disimpan di _jawaban[soalId].


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
    if (!_kiosk || !mounted) return;
    _juangPaused++;
    _catatPelanggaran();
    setState(() {});
    _snackIntrusi();
    if (_juangPaused > _penaltyLimit) _submit(auto: true);
  }

  void _onPinningWarning() {
    if (!_kiosk || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text('Pinning belum aktif — tekan Got it untuk melanjutkan ujian.', style: TextStyle(fontWeight: FontWeight.w500))),
          ],
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _snackIntrusi() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text('Terdeteksi jendela/overlay lain! Alarm aktif — kembali fokus ke ujian.', style: TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        backgroundColor: AppTheme.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_kiosk) {
        _juangPaused++;
        if (_sisaDetik > 0) Kiosk.alarmStart(maxVolume: true);
        _catatPelanggaran();
        if (_juangPaused > _penaltyLimit) _submit(auto: true);
      }
    } else if (state == AppLifecycleState.resumed) {
      Kiosk.alarmStop();
      if (_kiosk) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    }
  }

  Future<void> _catatPelanggaran() async {
    try {
      await Api.routerRpc('catat_pelanggaran', params: {'p_peserta': widget.pesertaId});
    } catch (_) {}
  }

  // ===== SIMPAN LOKAL (instan, gak ada internet) =====
  Future<void> _simpanLokal() async {
    await _store.saveAll(_jawaban, _ragu);
  }

  /// Dipanggil tiap murid tap jawaban: SIMPAN LOKAL SAJA (gak kirim server).
  Future<void> _saveJawaban(String soalId, {bool flush = false}) async {
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
    if (_loading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F8FC),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                 decoration: BoxDecoration(
                   color: AppTheme.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                 child: const CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 3),
              ),
              const SizedBox(height: 24),
               const Text('Menyiapkan Lingkungan Ujian', style: TextStyle(color: Color(0xFF17324D), fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
               Text('Mode terkunci • Anti-curang aktif', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        appBar: AppBar(title: const Text('Kesalahan'), backgroundColor: AppTheme.danger),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64, color: AppTheme.danger),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87)),
                const SizedBox(height: 24),
                FilledButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back), label: const Text('Kembali')),
              ],
            ),
          ),
        ),
      );
    }
    if (_soal.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ujian')),
        body: const Center(child: Text('Ujian tidak memiliki soal. Hubungi guru.')),
      );
    }

    final current = _soal[_idx];
    final curId = current['id'].toString();
    final jenis = current['jenis']?.toString() ?? 'pg';
    final opsi = current['opsi'];
    final opsiList = opsi is List ? opsi : <dynamic>[];
    final progress = (_idx + 1) / _soal.length;
    final answeredCount = _jawaban.values.where((v) => v != null && v!.isNotEmpty).length;
    final flaggedCount = _ragu.values.where((v) => v == true).length;
    final unansweredCount = _soal.length - answeredCount;
    final isLowTime = _sisaDetik < 300;
    final isCriticalTime = _sisaDetik < 60;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _catatPelanggaran();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(children: [Icon(Icons.block, color: Colors.white, size: 20), SizedBox(width: 12), Expanded(child: Text('Tombol kembali diblokir selama ujian', style: TextStyle(fontWeight: FontWeight.w600)))]),
              backgroundColor: AppTheme.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: Stack(
          children: [
            Column(
              children: [
                _buildHeader(progress, isLowTime, isCriticalTime, answeredCount, flaggedCount, unansweredCount),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: Colors.white,
                  valueColor: AlwaysStoppedAnimation(isLowTime ? AppTheme.danger : AppTheme.primary),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildQuestionCard(current, curId, jenis, opsiList),
                        const SizedBox(height: 16),
                        _buildOptions(curId, jenis, opsiList),
                        const SizedBox(height: 16),
                        _buildRaguChip(curId),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                _buildBottomNav(),
              ],
            ),
            // ===== FLOATING daftar soal (gede, tap luar buat tutup) =====
            if (_showPalette) ...[
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _showPalette = false),
                  child: Container(color: Colors.black.withValues(alpha: 0.45)),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: _buildPalette(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double progress, bool low, bool critical, int answered, int flagged, int unanswered) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, bottom: 12, left: 16, right: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
                   colors: [AppTheme.primary, AppTheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _isOwner ? const Color(0xFF14532D) : const Color(0xFF78350F),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _isOwner ? const Color(0xFF22C55E) : const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: _isOwner ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(_isOwner ? 'TERKUNCI' : 'TERBATAS',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const SizedBox(width: 6),
                    Icon(_isOwner ? Icons.lock : Icons.lock_open, color: Colors.white, size: 12),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: critical ? AppTheme.danger : low ? const Color(0xFFFEF3C7) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: critical ? [BoxShadow(color: AppTheme.danger.withValues(alpha: 0.4), blurRadius: 8)] : null,
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 16, color: critical ? Colors.white : low ? const Color(0xFF92400E) : AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(_fmt(_sisaDetik),
                        style: TextStyle(
                            color: critical ? Colors.white : low ? const Color(0xFF92400E) : AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 1)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${widget.ujian['nama'] ?? 'UJIAN'}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                     Text('Soal ${_idx + 1} dari ${_soal.length} • $answered terjawab • $unanswered kosong${flagged > 0 ? ' • $flagged ragu' : ''}${_juangPaused > 0 ? ' • keluar x$_juangPaused' : ''}', style: TextStyle(color: Colors.white.withValues(alpha: _juangPaused > 0 ? 1 : 0.7), fontSize: 12, fontWeight: _juangPaused > 0 ? FontWeight.bold : FontWeight.normal)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildCircleProgress(progress),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircleProgress(double progress) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: CircularProgressIndicator(value: progress, strokeWidth: 4, backgroundColor: Colors.white.withValues(alpha: 0.2), valueColor: const AlwaysStoppedAnimation(Colors.white)),
        ),
        Text('${((progress) * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> current, String curId, String jenis, List opsiList) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4))],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: jenis == 'essay' ? const Color(0xFFFEF3C7) : const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(jenis.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: jenis == 'essay' ? const Color(0xFF92400E) : AppTheme.primary)),
              ),
              const Spacer(),
              if (_ragu[curId] == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.flag, size: 12, color: AppTheme.accent), const SizedBox(width: 4), Text('RAGU', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accent))]),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Text('${_idx + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(current['soal']?.toString() ?? '', style: const TextStyle(fontSize: 16, height: 1.6, color: Color(0xFF0F172A), fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          if (current['gambar_url']?.toString().isNotEmpty == true) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE2E8F0)), borderRadius: BorderRadius.circular(12)),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280, maxHeight: 200),
                  child: Image.network(
                    current['gambar_url'].toString(),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 200,
                      height: 100,
                      color: const Color(0xFFF1F5F9),
                      child: const Center(child: Icon(Icons.broken_image, color: Color(0xFFCBD5E1))),
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _buildOptions(curId, jenis, opsiList),
        ],
      ),
    );
  }

  Widget _buildOptions(String curId, String jenis, List opsiList) {
    if (jenis == 'pg') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < opsiList.length; i++)
            _buildOptionCard(i, opsiList[i].toString(), curId, _jawaban[curId] == opsiList[i].toString()),
        ],
      );
    } else if (jenis == 'essay') {
      return Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)]),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(Icons.edit_note, size: 18, color: AppTheme.primary), SizedBox(width: 8), Text('Jawaban Essay', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary))]),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrlFor(curId),
              maxLines: 6,
              minLines: 4,
              readOnly: false,
              textInputAction: TextInputAction.newline,
              onChanged: (v) {
                // simpan lokal TANPA setState (biar keyboard/cursor tidak lompat)
                _jawaban[curId] = v;
                _belumKirim.add(curId);
                _simpanLokal();
              },
              decoration: InputDecoration(
                hintText: 'Ketik jawaban lengkap Anda di sini...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.primary, width: 2)),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildOptionCard(int index, String text, String curId, bool selected) {
    final letter = String.fromCharCode(65 + index);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? AppTheme.primary.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            setState(() => _jawaban[curId] = text);
            _saveJawaban(curId);
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? AppTheme.primary : const Color(0xFFE2E8F0), width: selected ? 2 : 1),
              boxShadow: selected ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))] : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primary : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                    border: Border.all(color: selected ? AppTheme.primary : const Color(0xFFE2E8F0)),
                  ),
                  alignment: Alignment.center,
                  child: Text(letter, style: TextStyle(color: selected ? Colors.white : const Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(text, style: TextStyle(fontSize: 14, height: 1.4, color: selected ? const Color(0xFF0F172A) : const Color(0xFF334155), fontWeight: selected ? FontWeight.w600 : FontWeight.normal))),
                const SizedBox(width: 8),
                Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: selected ? AppTheme.primary : const Color(0xFFCBD5E1), size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRaguChip(String curId) {
    final isRagu = _ragu[curId] ?? false;
    return GestureDetector(
      onTap: () {
        setState(() => _ragu[curId] = !isRagu);
        _saveJawaban(curId);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isRagu ? AppTheme.accent.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isRagu ? AppTheme.accent : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isRagu ? Icons.flag : Icons.outlined_flag, size: 18, color: isRagu ? AppTheme.accent : const Color(0xFF64748B)),
            const SizedBox(width: 8),
            Text(isRagu ? 'Ditandai ragu-ragu' : 'Tandai ragu-ragu', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isRagu ? AppTheme.accent : const Color(0xFF475569))),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    // Satu timer saja: sisa waktu ujian
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))],
        border: Border(top: BorderSide(color: const Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            OutlinedButton.icon(
              onPressed: _idx > 0 ? () => setState(() => _idx--) : null,
              icon: const Icon(Icons.chevron_left, size: 18),
              label: const Text('Sebelumnya'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => setState(() => _showPalette = !_showPalette),
                icon: Icon(_showPalette ? Icons.close : Icons.grid_view, size: 18),
                label: Text(_showPalette ? 'Tutup' : 'Daftar Soal'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (_idx < _soal.length - 1)
              FilledButton(
                onPressed: () => setState(() => _idx++),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Row(children: [const Text('Lanjut'), SizedBox(width: 4), Icon(Icons.chevron_right, size: 18)]),
              )
            else
              FilledButton(
                onPressed: _submitting ? null : _confirmSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.secondary,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _submitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Kumpulkan'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPalette() {
    final answeredCount = _jawaban.values.where((v) => v != null && v!.isNotEmpty).length;
    final maxH = MediaQuery.of(context).size.height * 0.62;
    return Material(
      elevation: 16,
      borderRadius: BorderRadius.circular(24),
      color: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Daftar Soal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$answeredCount/${_soal.length} terjawab',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Tutup',
                    icon: const Icon(Icons.close, size: 24),
                    onPressed: () => setState(() => _showPalette = false),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(
                children: [
                  _buildLegendDot(AppTheme.secondary, 'Dijawab'),
                  const SizedBox(width: 14),
                  _buildLegendDot(AppTheme.accent, 'Ragu'),
                  const SizedBox(width: 14),
                  _buildLegendDot(Colors.grey[400]!, 'Kosong'),
                ],
              ),
            ),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 72,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: _soal.length,
                itemBuilder: (context, i) {
                  final id = _soal[i]['id'].toString();
                  final answered = _jawaban[id] != null && _jawaban[id]!.isNotEmpty;
                  final ragu = _ragu[id] ?? false;
                  final isCurrent = i == _idx;
                  Color bg;
                  if (answered) bg = AppTheme.secondary;
                  else if (ragu) bg = AppTheme.accent;
                  else bg = Colors.grey[300]!;
                  return InkWell(
                    onTap: () => setState(() {
                      _idx = i;
                      _showPalette = false;
                    }),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isCurrent ? AppTheme.primary : bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isCurrent ? AppTheme.primary : Colors.transparent, width: 2),
                        boxShadow: isCurrent ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.35), blurRadius: 10)] : null,
                      ),
                      alignment: Alignment.center,
                      child: Text('${i + 1}', style: TextStyle(color: isCurrent || answered || ragu ? Colors.white : const Color(0xFF475569), fontWeight: FontWeight.bold, fontSize: 17)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
      ],
    );
  }

  Future<void> _confirmSubmit() async {
    // TIDAK ada lock submit — siswa bisa kumpulkan kapan aja
    // (auto-submit masih jalan saat timer habis)
    final belum = _soal.length - _jawaban.values.where((v) => v != null && v.isNotEmpty).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.assignment_turned_in, color: AppTheme.primary)), const SizedBox(width: 12), const Text('Kumpulkan Ujian?')]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(belum > 0 ? 'Masih ada $belum soal belum dijawab.' : 'Semua soal sudah dijawab.', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(belum > 0 ? 'Soal kosong akan dianggap salah. Yakin?' : 'Periksa kembali jawaban ragu-ragu sebelum mengumpulkan.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            if (belum > 0)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [Icon(Icons.warning_amber_rounded, color: AppTheme.accent, size: 18), const SizedBox(width: 8), Expanded(child: Text('$belum soal kosong', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600, fontSize: 13)))]),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Periksa Lagi')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.secondary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Ya, Kumpulkan'),
          ),
        ],
      ),
    );
    if (ok == true) await _submit();
  }
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
