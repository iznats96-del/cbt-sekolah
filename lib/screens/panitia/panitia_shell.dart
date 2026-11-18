import 'package:flutter/material.dart';

import '../../core/design.dart';
import '../../services/api.dart';
import '../../widgets/cetak_kartu_helper.dart';
import '../../widgets/dashboard_header.dart';
import '../home.dart';
import '../guru/scan_absen_screen.dart';
import 'monitoring_ujian_screen.dart';
import 'peserta_ujian_screen.dart';
import 'rekap_panitia_screen.dart';
import 'foto_siswa_screen.dart';
import '../../widgets/app_bottom_nav.dart';

class PanitiaShell extends StatefulWidget {
  const PanitiaShell({super.key});

  @override
  State<PanitiaShell> createState() => _PanitiaShellState();
}

class _PanitiaShellState extends State<PanitiaShell> {
  int _index = 0;
  void _go(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      PanitiaHome(onGo: _go),
      const MonitoringUjianScreen(),
      const PesertaUjianScreen(),
      const RekapPanitiaScreen(),
      const FotoSiswaScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _index,
        onChanged: _go,
        items: const [
          NavItem(Icons.space_dashboard_outlined, Icons.space_dashboard, 'Ringkasan'),
          NavItem(Icons.monitor_heart_outlined, Icons.monitor_heart, 'Monitoring'),
          NavItem(Icons.people_outline, Icons.people, 'Peserta'),
          NavItem(Icons.assessment_outlined, Icons.assessment, 'Rekap'),
          NavItem(Icons.photo_camera_outlined, Icons.photo_camera, 'Foto'),
        ],
      ),
    );
  }
}

class PanitiaHome extends StatefulWidget {
  final ValueChanged<int> onGo;
  const PanitiaHome({super.key, required this.onGo});

  @override
  State<PanitiaHome> createState() => _PanitiaHomeState();
}

class _PanitiaHomeState extends State<PanitiaHome> {
  Map<String, dynamic>? _stats;
  List<dynamic> _jadwal = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await Api.fallbackGetApi('/api/panitia/dashboard');
      if (!mounted) return;
      setState(() {
        _stats = res is Map ? Map<String, dynamic>.from(res['stats'] ?? {}) : null;
        _jadwal = (res is Map ? res['jadwal_hari_ini'] : null) as List? ?? [];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: DashboardHeader(
        title: 'RINGKASAN PANITIA',
        subtitle: 'Pantau pelaksanaan ujian hari ini',
        stats: [
          ('ujian aktif', '${(_stats ?? {})['ujian_aktif'] ?? 0}'),
          ('selesai', '${(_stats ?? {})['selesai_ujian'] ?? 0}'),
          ('hadir', '${(_stats ?? {})['hadir_hari_ini'] ?? 0}'),
        ],
        actions: const [LogoutButton()],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            if (_loading)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: Cbt.blue)))
            else ...[
              _buildStats(),
              const SizedBox(height: 18),
              Cbt.label('JADWAL HARI INI'),
              const SizedBox(height: 10),
              _buildJadwal(),
              const SizedBox(height: 20),
              Cbt.label('AKSES CEPAT'),
              const SizedBox(height: 10),
              _buildMenu(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    final s = _stats ?? {};
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: [
        _stat('Total siswa', s['total_siswa'], Icons.people_outline, Cbt.blue),
        _stat('Ujian aktif', s['ujian_aktif'], Icons.assignment_outlined, Cbt.teal),
        _stat('Selesai', s['selesai_ujian'], Icons.check_circle_outline, Cbt.blue),
        _stat('Hadir hari ini', s['hadir_hari_ini'], Icons.how_to_reg_outlined, Cbt.amber),
      ],
    );
  }

  Widget _stat(String label, dynamic value, IconData icon, Color color) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Cbt.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 17, color: color),
                const Spacer(),
                Text('$value', style: Cbt.display.copyWith(fontSize: 24, color: Cbt.ink)),
              ],
            ),
            const SizedBox(height: 6),
            Text(label, style: Cbt.caption),
          ],
        ),
      );

  Widget _buildJadwal() {
    if (_jadwal.isEmpty) {
      return Cbt.card(
        child: Row(
          children: [
            Icon(Icons.event_available_outlined, size: 20, color: Cbt.blue),
            const SizedBox(width: 10),
            Expanded(child: Text('Belum ada jadwal aktif hari ini.', style: Cbt.caption)),
          ],
        ),
      );
    }
    return Cbt.card(
      padding: const EdgeInsets.all(4),
      child: Column(
        children: _jadwal.take(4).map((j) {
          final m = j is Map ? Map<String, dynamic>.from(j) : <String, dynamic>{};
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Cbt.blue.withValues(alpha: 0.1),
              child: const Icon(Icons.schedule, size: 18, color: Cbt.blue),
            ),
            title: Text('${m['nama'] ?? m['ujian_nama'] ?? 'Ujian'}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Cbt.ink)),
            subtitle: Text('${m['mapel'] ?? ''} ${m['sesi_nama'] ?? ''}', style: Cbt.caption),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMenu() {
    final menu = [
      (Icons.monitor_heart_outlined, 'Monitoring', Cbt.blue, 1),
      (Icons.people_outline, 'Peserta ujian', Cbt.teal, 2),
      (Icons.assessment_outlined, 'Rekap nilai', Cbt.amber, 3),
      (Icons.qr_code_scanner, 'Scan absen', Cbt.blue, -1),
      (Icons.print_outlined, 'Cetak kartu', Cbt.teal, -2),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.1,
      children: menu.map((m) {
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            onTap: () {
              if (m.$4 == -1) {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ScanAbsenScreen()));
              } else if (m.$4 == -2) {
                pilihDanCetakKartu(context);
              } else {
                widget.onGo(m.$4);
              }
            },
            borderRadius: BorderRadius.circular(13),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(border: Border.all(color: Cbt.line), borderRadius: BorderRadius.circular(13)),
              child: Row(
                children: [
                  Icon(m.$1 as IconData, size: 20, color: m.$3 as Color),
                  const SizedBox(width: 10),
                  Expanded(child: Text(m.$2 as String,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Cbt.ink))),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
