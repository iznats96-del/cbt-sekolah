import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../../widgets/state_views.dart';
import '../../widgets/dashboard_header.dart';

class HasilScreen extends StatefulWidget {
  const HasilScreen({super.key});

  @override
  State<HasilScreen> createState() => _HasilScreenState();
}

class _HasilScreenState extends State<HasilScreen> {
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
          .from('hasil_ujian')
          .select(
              '*,peserta_ujian!inner(ujian!inner(nama,mata_pelajaran(nama)),siswa!inner(nama,nis))')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat hasil: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: const DashboardHeader(title: 'HASIL UJIAN', showBack: true),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_rows.isEmpty) {
      return const Center(
          child: Text('Belum ada hasil ujian', style: TextStyle(color: Colors.grey)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, i) {
          final r = _rows[i];
          final p = r['peserta_ujian'];
          final siswa = p is Map ? p['siswa'] : null;
          final ujian = p is Map ? p['ujian'] : null;
          final mapel = ujian is Map ? ujian['mata_pelajaran'] : null;
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                child: Text(
                  (siswa is Map ? siswa['nama'] : '')
                      .toString()
                      .isEmpty
                      ? '?'
                      : siswa['nama'].toString()[0],
                ),
              ),
              title: Text(
                  siswa is Map ? '${siswa['nama']}' : '',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                [
                  siswa is Map ? siswa['nis']?.toString() ?? '' : '',
                  ujian is Map ? ujian['nama']?.toString() ?? '' : '',
                  mapel is Map ? mapel['nama']?.toString() ?? '' : '',
                ].where((e) => e.isNotEmpty).join(' • '),
              ),
              trailing: Text(
                '${r['nilai'] ?? 0}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary),
              ),
            ),
          );
        },
      ),
    );
  }
}