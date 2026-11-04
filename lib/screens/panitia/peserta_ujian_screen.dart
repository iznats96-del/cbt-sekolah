import 'package:flutter/material.dart';

import '../../services/api.dart';
import '../../widgets/state_views.dart';

class PesertaUjianScreen extends StatefulWidget {
  const PesertaUjianScreen({super.key});

  @override
  State<PesertaUjianScreen> createState() => _PesertaUjianScreenState();
}

class _PesertaUjianScreenState extends State<PesertaUjianScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  String _filterStatus = 'semua';

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
      var query = Api.client
          .from('peserta_ujian')
          .select('*,ujian!inner(nama,status),siswa!inner(nama,nis)');

      if (_filterStatus != 'semua') {
        query = query.eq('status', _filterStatus);
      }

      final rows = await query.order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat peserta: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: const Text('Daftar Peserta')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text('Filter: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _filterStatus,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'semua', child: Text('Semua Status')),
                      DropdownMenuItem(value: 'belum', child: Text('Belum Mulai')),
                      DropdownMenuItem(value: 'mengikuti', child: Text('Sedang Mengerjakan')),
                      DropdownMenuItem(value: 'selesai', child: Text('Selesai')),
                      DropdownMenuItem(value: 'absen', child: Text('Absen')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _filterStatus = v);
                      _load();
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_rows.isEmpty) {
      return const Center(
          child: Text('Tidak ada peserta ditemukan',
              style: TextStyle(color: Colors.grey)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final p = _rows[i];
          final siswa = p['siswa'];
          final ujian = p['ujian'];
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _statusColor(p['status']),
                child: Text(
                  (p['status'] ?? '?')[0].toString().toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(siswa is Map ? siswa['nama'] ?? '' : '',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  'NIS: ${siswa is Map ? siswa['nis'] ?? '-' : '-'}\n'
                  'Ujian: ${ujian is Map ? ujian['nama'] ?? '-' : '-'}'),
              trailing: Chip(
                label: Text((p['status'] ?? '').toString().toUpperCase(),
                    style: const TextStyle(fontSize: 10)),
                backgroundColor: _statusColor(p['status']).withValues(alpha: 0.15),
                side: BorderSide.none,
              ),
            ),
          );
        },
      ),
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'mengikuti':
        return const Color(0xFF2196F3);
      case 'selesai':
        return const Color(0xFF4CAF50);
      case 'absen':
        return const Color(0xFFF44336);
      case 'gagal':
        return const Color(0xFF9E9E9E);
      default:
        return const Color(0xFFFF9800);
    }
  }
}