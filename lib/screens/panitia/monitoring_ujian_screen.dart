import 'package:flutter/material.dart';

import '../../core/design.dart';
import '../../services/api.dart';
import '../../widgets/state_views.dart';
import 'atur_jadwal_panitia_screen.dart';

class MonitoringUjianScreen extends StatefulWidget {
  const MonitoringUjianScreen({super.key});

  @override
  State<MonitoringUjianScreen> createState() => _MonitoringUjianScreenState();
}

class _MonitoringUjianScreenState extends State<MonitoringUjianScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  final _cari = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await Api.client
          .from('ujian')
          .select('*,mata_pelajaran(nama),sesi(nama)')
          .inFilter('status', ['aktif', 'selesai'])
          .order('tanggal', ascending: false);
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat ujian: $e';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _cari.text.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows.where((u) {
      final mp = u['mata_pelajaran'];
      final sesi = u['sesi'];
      return '${u['nama'] ?? ''} ${mp is Map ? mp['nama'] : ''} '
              '${sesi is Map ? sesi['nama'] : ''} ${u['status'] ?? ''}'
          .toLowerCase()
          .contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cbt.paper,
      appBar: AppBar(
        backgroundColor: Cbt.paper,
        foregroundColor: Cbt.ink,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Monitoring Ujian', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            Text('${_rows.length} ujian aktif & selesai', style: Cbt.caption),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Cbt.blue));
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Cbt.searchField(
            controller: _cari,
            hint: 'Cari nama ujian, mapel, atau sesi…',
            onChanged: (_) => setState(() {}),
          ),
        ),
        Expanded(
          child: _filtered.isEmpty
              ? Cbt.empty(
                  icon: Icons.search_off_rounded,
                  title: _rows.isEmpty ? 'Belum ada ujian' : 'Tidak ada yang cocok',
                  subtitle: _rows.isEmpty ? 'Ujian aktif/selesai akan muncul di sini.' : 'Coba kata kunci lain.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 9),
                    itemBuilder: (context, i) => _buildCard(_filtered[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCard(Map<String, dynamic> u) {
    final mp = u['mata_pelajaran'];
    final sesi = u['sesi'];
    final aktif = u['status'] == 'aktif';
    final warna = aktif ? Cbt.teal : Cbt.muted;
    return Cbt.card(
      padding: const EdgeInsets.all(14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AturJadwalPanitiaScreen(
                ujianId: u['id'] as String,
                ujianNama: u['nama'] ?? '',
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: warna.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(aktif ? Icons.play_circle_outline : Icons.check_circle_outline, color: warna),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${u['nama'] ?? ''}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Cbt.ink)),
                    const SizedBox(height: 4),
                    Text('${mp is Map ? mp['nama'] : '-'} • ${sesi is Map ? sesi['nama'] : '-'}',
                        style: Cbt.caption),
                    Text('${u['tanggal'] ?? ''}', style: Cbt.caption),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: warna.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
                child: Text('${u['status'] ?? ''}',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: warna)),
              ),
              const Icon(Icons.chevron_right, color: Cbt.muted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
