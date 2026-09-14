import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';

class PresensiScreen extends StatefulWidget {
  const PresensiScreen({super.key});

  @override
  State<PresensiScreen> createState() => _PresensiScreenState();
}

class _PresensiScreenState extends State<PresensiScreen> {
  List<Map<String, dynamic>> _siswa = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await Api.client
          .from('siswa')
          .select('*,kelas(nama)')
          .order('nama');
      if (!mounted) return;
      setState(() {
        _siswa = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _siswa = [];
        _loading = false;
      });
    }
  }

  Future<void> _absen(Map<String, dynamic> s, String status) async {
    try {
      final today = DateTime.now().toIso8601String().split('T').first;
      // cek existing
      final existing = await Api.client
          .from('kehadiran')
          .select()
          .eq('siswa_id', s['id'])
          .eq('tanggal', today);
      if (existing.isNotEmpty) {
        await Api.client
            .from('kehadiran')
            .update({'status': status})
            .eq('id', existing.first['id']);
      } else {
        await Api.client.from('kehadiran').insert({
          'siswa_id': s['id'],
          'tanggal': today,
          'status': status,
          'guru_id': Api.user?.id,
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${s['nama']}: $status')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: const Text('Presensi Harian')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _siswa.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final s = _siswa[i];
                  final kelas =
                      s['kelas'] is Map ? (s['kelas'] as Map)['nama'] ?? '' : '';
                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      title: Text('${s['nama']}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text([s['nis'], kelas].where((e) => '${e ?? ''}'.isNotEmpty).join(' • ')),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StatusChip(label: 'H', color: AppTheme.secondary, onTap: () => _absen(s, 'hadir')),
                          const SizedBox(width: 4),
                          _StatusChip(label: 'I', color: AppTheme.accent, onTap: () => _absen(s, 'izin')),
                          const SizedBox(width: 4),
                          _StatusChip(label: 'S', color: AppTheme.primary, onTap: () => _absen(s, 'sakit')),
                          const SizedBox(width: 4),
                          _StatusChip(label: 'A', color: AppTheme.danger, onTap: () => _absen(s, 'alpa')),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _StatusChip({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }
}