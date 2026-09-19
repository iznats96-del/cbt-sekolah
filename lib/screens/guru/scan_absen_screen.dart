import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import 'presensi_screen.dart';

/// Absen barcode (Opsi A): guru scan QR NIS milik murid.
/// QR murid = NIS (bisa dari layar "Kartu Saya" murid / kartu cetak).
class ScanAbsenScreen extends StatefulWidget {
  const ScanAbsenScreen({super.key});

  @override
  State<ScanAbsenScreen> createState() => _ScanAbsenScreenState();
}

class _ScanAbsenScreenState extends State<ScanAbsenScreen> {
  final MobileScannerController _ctrl = MobileScannerController();
  final TextEditingController _nisCtrl = TextEditingController();

  bool _busy = false;
  bool _torch = false;
  String? _msg;
  Color _msgColor = AppTheme.secondary;
  final List<Map<String, String>> _riwayat = [];
  int _hadirHariIni = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    _nisCtrl.dispose();
    super.dispose();
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _prosesNis(String raw) async {
    final nis = raw.trim();
    if (nis.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      // 1. cari murid berdasar NIS
      final rows = await Api.client
          .from('siswa')
          .select('id,nama,nis,kelas(nama)')
          .eq('nis', nis)
          .limit(1);
      if (rows.isEmpty) {
        _hasil('NIS $nis tidak terdaftar', AppTheme.danger);
        return;
      }
      final s = Map<String, dynamic>.from(rows.first as Map);
      final kelas = s['kelas'] is Map ? '${(s['kelas'] as Map)['nama'] ?? ''}' : '';

      // 2. upsert kehadiran hari ini -> hadir
      final today = _today();
      final ex = await Api.client
          .from('kehadiran')
          .select('id')
          .eq('siswa_id', '${s['id']}')
          .eq('tanggal', today)
          .limit(1);
      if ((ex as List).isNotEmpty) {
        await Api.client.from('kehadiran').update(
            {'status': 'hadir', 'guru_id': Api.user?.id}).eq(
            'id', '${(ex as List).first['id']}');
      } else {
        await Api.client.from('kehadiran').insert({
          'siswa_id': '${s['id']}',
          'tanggal': today,
          'status': 'hadir',
          'guru_id': Api.user?.id,
        });
      }

      setState(() {
        _riwayat.insert(0, {
          'nama': '${s['nama']}',
          'nis': '${s['nis']}',
          'kelas': kelas,
        });
        _hadirHariIni++;
      });
      _hasil('${s['nama']} • HADIR', AppTheme.secondary);
    } catch (e) {
      _hasil('Gagal: $e', AppTheme.danger);
    } finally {
      // jeda biar 1 scan = 1 catat (gak dobel)
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) setState(() => _busy = false);
    }
  }

  void _hasil(String m, Color c) {
    if (!mounted) return;
    setState(() {
      _msg = m;
      _msgColor = c;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m),
      backgroundColor: c,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Scan Absen'),
        actions: [
          IconButton(
            tooltip: _torch ? 'Matikan lampu' : 'Nyalakan lampu',
            icon: Icon(_torch ? Icons.flash_on : Icons.flash_off),
            onPressed: () async {
              await _ctrl.toggleTorch();
              if (mounted) setState(() => _torch = !_torch);
            },
          ),
          IconButton(
            tooltip: 'Absen manual (daftar murid)',
            icon: const Icon(Icons.list_alt_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PresensiScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // kamera
          AspectRatio(
            aspectRatio: 1.2,
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _ctrl,
                  onDetect: (cap) {
                    final v = cap.barcodes.isNotEmpty
                        ? cap.barcodes.first.rawValue
                        : null;
                    if (v != null && v.isNotEmpty) _prosesNis(v);
                  },
                ),
                // bingkai bidik
                Center(
                  child: Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: _busy ? Colors.grey : AppTheme.secondary,
                          width: 3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Text(
                    _busy ? 'Memproses...' : 'Arahkan kamera ke QR murid',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(blurRadius: 6)]),
                  ),
                ),
              ],
            ),
          ),
          // status terakhir
          if (_msg != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _msgColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _msgColor.withOpacity(0.3)),
              ),
              child: Text(_msg!,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: _msgColor)),
            ),
          // input NIS manual (cadangan kalau QR rusak/kamera mati)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nisCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'NIS manual (kalau QR tak terbaca)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (v) {
                      _prosesNis(v);
                      _nisCtrl.clear();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    _prosesNis(_nisCtrl.text);
                    _nisCtrl.clear();
                  },
                  child: const Text('Absen'),
                ),
              ],
            ),
          ),
          // riwayat sesi ini
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Row(
              children: [
                Text('Tercatat sesi ini: $_hadirHariIni',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_riwayat.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() {
                      _riwayat.clear();
                      _hadirHariIni = 0;
                    }),
                    child: const Text('Bersihkan'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _riwayat.isEmpty
                ? const Center(
                    child: Text('Belum ada yang di-scan',
                        style: TextStyle(color: Colors.grey)))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: _riwayat.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, i) {
                      final r = _riwayat[i];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          dense: true,
                          leading: const CircleAvatar(
                            backgroundColor: AppTheme.secondary,
                            child: Icon(Icons.check,
                                color: Colors.white, size: 18),
                          ),
                          title: Text('${r['nama']}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              ['${r['nis']}', '${r['kelas']}']
                                  .where((e) => e.isNotEmpty)
                                  .join(' • ')),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
