import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../../services/kiosk.dart';

class PelaksanaanScreen extends StatefulWidget {
  final Map<String, dynamic> ujian;
  final String pesertaId;
  const PelaksanaanScreen({
    super.key,
    required this.ujian,
    required this.pesertaId,
  });

  @override
  State<PelaksanaanScreen> createState() => _PelaksanaanScreenState();
}

class _PelaksanaanScreenState extends State<PelaksanaanScreen>
    with WidgetsBindingObserver {
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
  bool _kirimGagal = false;
  String? _error;

  int _juangPaused = 0;
  bool _kiosk = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final menit = (widget.ujian['alokasi_menit'] as num?)?.toInt() ?? 90;
    _durasiDetik = menit * 60;
    _sisaDetik = _durasiDetik;
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    Kiosk.alarmStop();
    Kiosk.setSecure(false);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await Api.client
          .rpc('soal_milik_ujian', params: {'p_peserta': widget.pesertaId});
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
      if (!mounted) return;
      setState(() {
        _kiosk = true;
        _loading = false;
      });
      Kiosk.setSecure(true); // anti-screenshot hanya selama ujian
      _startTimer();
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

  // ---------- Anti-cheat ----------
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_kiosk) {
        _juangPaused++;
        if (_sisaDetik > 0) Kiosk.alarmStart(maxVolume: true);
        _catatPelanggaran();
        if (_juangPaused > _penaltyLimit) {
          _submit(auto: true);
        }
      }
    } else if (state == AppLifecycleState.resumed) {
      Kiosk.alarmStop();
    }
  }

  Future<void> _catatPelanggaran() async {
    try {
      await Api.client.rpc('catat_pelanggaran',
          params: {'p_peserta': widget.pesertaId});
    } catch (_) {}
  }

  // ---------- Simpan jawaban (auto, tanpa kunci) ----------
  Future<void> _saveJawaban(String soalId, {bool flush = false}) async {
    try {
      await Api.client.rpc('simpan_jawaban', params: {
        'p_peserta': widget.pesertaId,
        'p_soal': soalId,
        'p_jawaban': _jawaban[soalId] ?? '',
        'p_ragu': _ragu[soalId] ?? false,
      });
      if (mounted && _kirimGagal) setState(() => _kirimGagal = false);
    } catch (_) {
      if (flush && mounted) setState(() => _kirimGagal = true);
    }
  }

  Future<void> _submit({bool auto = false}) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    _timer?.cancel();
    Kiosk.alarmStop();
    try {
      // sinkron final semua jawaban
      for (final s in _soal) {
        await _saveJawaban(s['id'].toString(), flush: true);
      }
      await Api.client.rpc('kumpulkan_ujian', params: {'p_peserta': widget.pesertaId});
      if (!mounted) return;
      _kiosk = false;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => _SelesaiScreen(title: auto ? 'Waktu habis' : 'Ujian selesai'),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengumpulkan: $e'), backgroundColor: AppTheme.danger),
      );
      if (!auto) _startTimer();
    }
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
        backgroundColor: AppTheme.primary,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Menyiapkan ujian...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kesalahan')),
        body: Center(child: Text(_error!)),
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _catatPelanggaran();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Anda tidak dapat keluar dari ujian. Lanjutkan mengerjakan.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text('${widget.ujian['nama'] ?? 'Ujian'}',
              overflow: TextOverflow.ellipsis),
          automaticallyImplyLeading: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _sisaDetik < 60 ? AppTheme.danger : Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.timer, size: 16),
                      const SizedBox(width: 6),
                      Text(_fmt(_sisaDetik),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFFF4F6FA),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Soal ${_idx + 1} dari ${_soal.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  if (_kirimGagal)
                    const Text('● tersimpan lokal',
                        style: TextStyle(fontSize: 10, color: AppTheme.danger)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text('${_idx + 1}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(current['soal']?.toString() ?? '',
                                      style: const TextStyle(fontSize: 16, height: 1.5)),
                                ),
                              ],
                            ),
                            if (current['gambar_url']?.toString().isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFE0E0E0)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 260),
                                    child: Image.network(
                                      current['gambar_url'].toString(),
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, e, s) =>
                                          const SizedBox.shrink(),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            if (jenis == 'pg' ||
                                (jenis == 'jodoh' && opsiList.isNotEmpty)) ...[
                              if (jenis == 'jodoh')
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: Text('Pilih pasangan yang tepat:',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                          fontStyle: FontStyle.italic)),
                                ),
                              for (var i = 0; i < opsiList.length; i++)
                                RadioListTile<String>(
                                  value: opsiList[i].toString(),
                                  groupValue: _jawaban[curId],
                                  title: Text(
                                      '${String.fromCharCode(65 + i)}. ${opsiList[i]}'),
                                  onChanged: (v) {
                                    setState(() => _jawaban[curId] = v);
                                    _saveJawaban(curId);
                                  },
                                  dense: true,
                                ),
                            ] else if (jenis == 'essay') ...[
                              TextField(
                                controller:
                                    TextEditingController(text: _jawaban[curId] ?? ''),
                                maxLines: 5,
                                onChanged: (v) {
                                  _jawaban[curId] = v;
                                  _saveJawaban(curId);
                                },
                                decoration: const InputDecoration(
                                  hintText: 'Tulis jawaban Anda...',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: _ragu[curId] ?? false,
                          onChanged: (v) {
                            setState(() => _ragu[curId] = v ?? false);
                            _saveJawaban(curId);
                          },
                        ),
                        const Text('Tandai ragu-ragu'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    OutlinedButton(
                      onPressed: _idx > 0
                          ? () => setState(() => _idx--)
                          : null,
                      child: const Text('Sebelum'),
                    ),
                    const Spacer(),
                    if (_idx < _soal.length - 1)
                      FilledButton(
                        onPressed: () => setState(() => _idx++),
                        child: const Text('Berikutnya'),
                      )
                    else
                      FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.secondary),
                        onPressed: _submitting ? null : _confirmSubmit,
                        child: _submitting
                            ? const SizedBox(
                                height: 18, width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Selesai & Kumpulkan'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _soalNavigator(),
      ),
    );
  }

  Widget _soalNavigator() {
    return Container(
      height: 110,
      color: const Color(0xFFF4F6FA),
      padding: const EdgeInsets.all(8),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 44,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
        ),
        itemCount: _soal.length,
        itemBuilder: (context, i) {
          final id = _soal[i]['id'].toString();
          final answered = _jawaban[id] != null && _jawaban[id]!.isNotEmpty;
          final ragu = _ragu[id] ?? false;
          final isCurrent = i == _idx;
          Color bg;
          if (answered) {
            bg = AppTheme.secondary;
          } else if (ragu) {
            bg = AppTheme.accent;
          } else {
            bg = Colors.grey[400]!;
          }
          return InkWell(
            onTap: () => setState(() => _idx = i),
            child: Container(
              decoration: BoxDecoration(
                color: isCurrent ? AppTheme.primary : bg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCurrent ? AppTheme.primary : Colors.transparent,
                ),
              ),
              alignment: Alignment.center,
              child: Text('${i + 1}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmSubmit() async {
    final belum = _soal.length - _jawaban.values.where((v) => v != null && v.isNotEmpty).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Kumpulkan Ujian?'),
        content: Text(belum > 0
            ? 'Masih ada $belum soal belum dijawab. Yakin ingin mengumpulkan?'
            : 'Semua soal sudah dijawab. Yakin ingin mengumpulkan?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Periksa Lagi')),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Kumpulkan'),
          ),
        ],
      ),
    );
    if (ok == true) await _submit();
  }
}

class _SelesaiScreen extends StatelessWidget {
  final String title;
  const _SelesaiScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: PopScope(
        canPop: true,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    title == 'Waktu habis'
                        ? Icons.timer_off
                        : Icons.check_circle_outline,
                    size: 72,
                    color: AppTheme.secondary),
                const SizedBox(height: 16),
                Text(title,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                    'Jawaban Anda telah dikumpulkan.\nNilai muncul otomatis bila kunci jawaban sudah diisi guru.',
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  child: const Text('Kembali ke Beranda'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}