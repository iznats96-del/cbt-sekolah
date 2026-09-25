import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../home.dart';
import 'presensi_screen.dart';
import 'rekap_absen_screen.dart';

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

  Future<void> _prosesNis(String raw, {String status = 'hadir'}) async {
    final nis = raw.trim();
    if (nis.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      // 1x panggil RPC atomik (anti-duplikat di server)
      final res = await Api.client.rpc('catat_hadir',
          params: {'p_nis': nis, 'p_status': status});
      final m = Map<String, dynamic>.from(res as Map);
      final nama = '${m['nama'] ?? nis}';
      final baru = m['baru'] == true;

      // cari kelas murid untuk tampilan (opsional, gagal pun tak masalah)
      String kelas = '';
      try {
        final rows = await Api.client
            .from('siswa')
            .select('kelas(nama)')
            .eq('nis', nis)
            .limit(1);
        if ((rows as List).isNotEmpty) {
          final k = (rows.first as Map)['kelas'];
          if (k is Map) kelas = '${k['nama'] ?? ''}';
        }
      } catch (_) {}

      setState(() {
        // riwayat sesi: kalau NIS sudah ada, pindah ke atas (jangan dobel)
        _riwayat.removeWhere((r) => r['nis'] == nis);
        _riwayat.insert(0, {'nama': nama, 'nis': nis, 'kelas': kelas});
        _hadirHariIni = _riwayat.length;
      });
      _hasil(
          baru ? '$nama • HADIR' : '$nama • sudah tercatat (diperbarui)',
          baru ? AppTheme.secondary : AppTheme.primary);
    } catch (e) {
      final s = e.toString();
      _hasil(
          s.contains('tidak terdaftar')
              ? 'NIS $nis tidak terdaftar'
              : s.contains('Hanya guru')
                  ? 'Akses ditolak'
                  : 'Gagal: ${_clean(s)}',
          AppTheme.danger);
    } finally {
      // jeda biar 1 scan = 1 catat (gak dobel)
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) setState(() => _busy = false);
    }
  }

  String _clean(String s) {
    final m = RegExp(r'"message":"([^"]+)"').firstMatch(s) ??
        RegExp(r': (.+)$').firstMatch(s);
    return m?.group(1) ?? s;
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
            tooltip: 'Rekap per kelas & jurusan',
            icon: const Icon(Icons.insert_chart_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RekapAbsenScreen()),
            ),
          ),
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
          if (!Navigator.of(context).canPop()) const LogoutButton(),
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
                color: _msgColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _msgColor.withValues(alpha: 0.3)),
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
