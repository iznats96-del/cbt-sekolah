import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';

class PelaksanaanScreen extends StatefulWidget {
  final Map<String, dynamic> ujian;
  const PelaksanaanScreen({super.key, required this.ujian});

  @override
  State<PelaksanaanScreen> createState() => _PelaksanaanScreenState();
}

class _PelaksanaanScreenState extends State<PelaksanaanScreen>
    with WidgetsBindingObserver {
  final int _penaltyLimit = 3; // keluar app > 3x -> auto submit

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

  String? _pesertaId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _durasiDetik = (widget.ujian['alokasi_menit'] as num?)?.toInt() ?? 90;
    _durasiDetik *= 60;
    _sisaDetik = _durasiDetik;
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = Api.user?.id;
    if (userId == null) return;
    try {
      final soalIds = (widget.ujian['soal_list'] as List?)?.map((e) => e.toString()).toList() ?? [];
      List<Map<String, dynamic>> soal = [];
      if (soalIds.isNotEmpty) {
        final rows = await Api.client
            .from('bank_soal')
            .select('id,soal,jenis,opsi,kunci,bobot,mapel_id')
            .inFilter('id', soalIds);
        soal = List<Map<String, dynamic>>.from(rows);
        // urutkan sesuai soal_list
        final m = {for (final s in soal) s['id'].toString(): s};
        soal = [for (final id in soalIds) if (m[id] != null) m[id]!];
      }

      // buat/konek peserta_ujian
      final profile = await Api.currentProfile();
      final siswaRows = await Api.client
          .from('siswa')
          .select('id')
          .eq('profile_id', userId)
          .limit(1);
      String? siswaId = siswaRows.isNotEmpty ? siswaRows.first['id'].toString() : null;

      // jika tidak ada siswa terhubung, buat placeholder
      if (siswaId == null) {
        final ins = await Api.client.from('siswa').insert({
          'nis': 'TMP${DateTime.now().millisecondsSinceEpoch}',
          'nama': profile?['nama'] ?? 'Peserta',
          'profile_id': userId,
        }).select('id');
        siswaId = ins.first['id'].toString();
      }

      // cek peserta_ujian existing
      final peserta = await Api.client
          .from('peserta_ujian')
          .select()
          .eq('ujian_id', widget.ujian['id'])
          .eq('siswa_id', siswaId!);
      if (peserta.isNotEmpty) {
        _pesertaId = peserta.first['id'].toString();
        if (peserta.first['status'] == 'selesai') {
          _finishLocal(title: 'Sudah dikerjakan');
          return;
        }
      } else {
        final ins = await Api.client.from('peserta_ujian').insert({
          'ujian_id': widget.ujian['id'],
          'siswa_id': siswaId,
          'status': 'mengikuti',
          'started_at': DateTime.now().toUtc().toIso8601String(),
        }).select('id');
        _pesertaId = ins.first['id'].toString();
      }

      if (!mounted) return;
      setState(() {
        _soal = soal;
        _kiosk = true;
        _loading = false;
      });
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // anti-cheat: catat saat keluar app
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_kiosk) _juangPaused++;
      _catatPelanggaran();
      if (_juangPaused > _penaltyLimit) {
        _submit(auto: true);
      }
    }
  }

  Future<void> _catatPelanggaran() async {
    try {
      if (_pesertaId == null) return;
      final cur = await Api.client
          .from('hasil_ujian')
          .select('pelanggaran,rincian_pelanggaran')
          .eq('peserta_ujian_id', _pesertaId!);
      int pel = 0;
      List<dynamic> rincian = [];
      if (cur.isNotEmpty) {
        pel = (cur.first['pelanggaran'] as num?)?.toInt() ?? 0;
        final r = cur.first['rincian_pelanggaran'];
        if (r is List) rincian = r;
      }
      rincian.add({
        'waktu': DateTime.now().toIso8601String(),
        'jenis': 'keluar_app_atau_pindah_layar',
      });
      await Api.client.from('hasil_ujian').upsert({
        'peserta_ujian_id': _pesertaId,
        'pelanggaran': pel + 1,
        'rincian_pelanggaran': rincian,
      });
    } catch (_) {}
  }

  Future<void> _submit({bool auto = false}) async {
    final pesertaId = _pesertaId;
    if (_submitting || pesertaId == null) return;
    setState(() => _submitting = true);
    _timer?.cancel();
    try {
      // simpan jawaban soal tersisa
      for (final s in _soal) {
        final jawaban = _jawaban[s['id'].toString()];
        if (jawaban != null) {
          await Api.client.from('jawaban_siswa').upsert({
            'peserta_ujian_id': pesertaId,
            'soal_id': s['id'],
            'jawaban': jawaban,
            'ragu_ragu': (_ragu[s['id'].toString()] ?? false),
          });
        }
      }
      // tandai selesai
      await Api.client.from('peserta_ujian').update({
        'status': 'selesai',
        'finished_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', pesertaId);
      // hitung nilai otomatis (server side function optional; fallback local)
      try {
        // coba panggil RPC bila ada
        await Api.client.rpc('hitung_nilai', params: {
          'p_peserta': pesertaId,
        });
      } catch (_) {
        _hitungNilaiLokal();
      }
      if (!mounted) return;
      _finishLocal(title: auto ? 'Waktu habis' : 'Ujian selesai');
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: AppTheme.danger),
      );
      // jangan matikan timer di sini, lanjut
      if (!auto) _startTimer();
    }
  }

  Future<void> _hitungNilaiLokal() async {
    try {
      int benar = 0, salah = 0, kosong = 0;
      for (final s in _soal) {
        final j = _jawaban[s['id'].toString()];
        if (j == null) {
          kosong++;
          continue;
        }
        final kunci = s['kunci'];
        bool ok = false;
        if (kunci is Map && kunci['jawaban'] != null) {
          ok = j.trim().toLowerCase() == kunci['jawaban'].toString().trim().toLowerCase();
        } else if (kunci is List) {
          ok = kunci.map((k) => k.toString().toLowerCase()).toSet().containsAll(
              j.split(',').map((x) => x.trim().toLowerCase()).toSet());
        }
        if (ok) {
          benar++;
        } else {
          salah++;
        }
      }
      final total = benar + salah + kosong;
      final persen = total == 0 ? 0 : (benar * 100 / total);
      if (_pesertaId != null) {
        await Api.client.from('hasil_ujian').upsert({
          'peserta_ujian_id': _pesertaId,
          'jumlah_benar': benar,
          'jumlah_salah': salah,
          'jumlah_kosong': kosong,
          'skor': benar,
          'nilai': persen.roundToDouble(),
          'dinilai': true,
        });
      }
    } catch (_) {}
  }

  void _finishLocal({required String title}) {
    _kiosk = false;
    _timer?.cancel();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => _SelesaiScreen(title: title),
    ));
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

    // format waktu
    final mm = (_sisaDetik ~/ 60).toString().padLeft(2, '0');
    final ss = (_sisaDetik % 60).toString().padLeft(2, '0');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('${widget.ujian['nama'] ?? 'Ujian'}'),
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
                    Text('$mm:$ss', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: PopScope(
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
        child: Column(
          children: [
            // soal nomor
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFFF4F6FA),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Soal ${_idx + 1} dari ${_soal.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    'PG' == jenis ? '' : '',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // kartu soal + navigasi
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
                                  child: Text(
                                    '${_idx + 1}',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    current['soal']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 16, height: 1.5),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (jenis == 'pg') ...[
                              for (var i = 0; i < opsiList.length; i++)
                                RadioListTile<String>(
                                  value: opsiList[i].toString(),
                                  groupValue: _jawaban[curId],
                                  title: Text('${String.fromCharCode(65 + i)}. ${opsiList[i]}'),
                                  onChanged: (v) => setState(() => _jawaban[curId] = v),
                                  dense: true,
                                ),
                            ] else ...[
                              TextField(
                                controller: TextEditingController(
                                    text: _jawaban[curId] ?? ''),
                                maxLines: 4,
                                decoration: const InputDecoration(
                                  hintText: 'Tulis jawaban Anda...',
                                ),
                                onChanged: (v) => setState(() => _jawaban[curId] = v),
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
                          onChanged: (v) => setState(() => _ragu[curId] = v ?? false),
                        ),
                        const Text('Tandai ragu-ragu'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // navigasi bawah
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
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.secondary),
                        onPressed: _submitting
                            ? null
                            : () => _confirmSubmit(),
                        child: _submitting
                            ? const SizedBox(
                                height: 18, width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Selesai & Kumpulkan'),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // Navigator soal (grid)
      bottomNavigationBar: _soalNavigator(context),
    );
  }

  Widget _soalNavigator(BuildContext context) {
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
              child: Text(
                '${i + 1}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmSubmit() async {
    final belum = _soal.length - (_jawaban.values.where((v) => v != null && v.isNotEmpty).length);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Kumpulkan Ujian?'),
        content: Text(belum > 0
            ? 'Masih ada $belum soal belum dijawab. Yakin ingin mengumpulkan?'
            : 'Semua soal sudah dijawab. Yakin ingin mengumpulkan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Periksa Lagi')),
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(title == 'Waktu habis' ? Icons.timer_off : Icons.check_circle_outline,
                  size: 72, color: AppTheme.secondary),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Jawaban Anda telah dikumpulkan.', textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Kembali ke Beranda'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}