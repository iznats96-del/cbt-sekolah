import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: const Text('Monitoring Ujian')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_rows.isEmpty) {
      return const Center(
          child: Text('Tidak ada ujian aktif/selesai',
              style: TextStyle(color: Colors.grey)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final u = _rows[i];
          final mp = u['mata_pelajaran'];
          final sesi = u['sesi'];
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(u['nama'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text('Mapel: ${mp is Map ? mp['nama'] : '-'}'),
                  Text('Tanggal: ${u['tanggal'] ?? '-'}'),
                  Text('Sesi: ${sesi is Map ? sesi['nama'] : '-'}'),
                  const SizedBox(height: 4),
                  Chip(
                    label: Text(
                      (u['status'] ?? '').toString().toUpperCase(),
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: u['status'] == 'aktif'
                        ? const Color(0xFFE8F5E9)
                        : const Color(0xFFFFF3E0),
                    side: BorderSide.none,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
               onTap: () {
               Navigator.of(context).push(
               MaterialPageRoute(
               builder: (_) => AturJadwalPanitiaScreen(
               ujianId: u['id'] as String,
               ujianNama: u['nama'] ?? '',
               ),
               ),
               );
               },
            ),
          );
        },
      ),
    );
  }
}