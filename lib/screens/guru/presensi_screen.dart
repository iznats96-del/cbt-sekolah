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
      // pakai RPC atomik (anti-duplikat, 1x panggil)
      final res = await Api.client.rpc('catat_hadir', params: {
        'p_nis': '${s['nis'] ?? ''}',
        'p_status': status,
      });
      final m = Map<String, dynamic>.from(res as Map);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${m['nama'] ?? s['nama']}: $status${m['baru'] == false ? ' (diperbarui)' : ''}')),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(msg.contains('tidak terdaftar')
                ? 'NIS tidak terdaftar'
                : 'Gagal: $e'),
            backgroundColor: AppTheme.danger),
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
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }
}