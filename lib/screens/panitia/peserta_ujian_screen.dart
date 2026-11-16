import 'package:flutter/material.dart';

import '../../services/api.dart';
import '../../widgets/state_views.dart';

class PesertaUjianScreen extends StatefulWidget {
  const PesertaUjianScreen({super.key});

  @override
  State<PesertaUjianScreen> createState() => _PesertaUjianScreenState();
}

class _PesertaUjianScreenState extends State<PesertaUjianScreen> {
  List<Map<String, dynamic>> _jurusanList = [];
  List<Map<String, dynamic>> _kelasList = [];
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;
  String _filterStatus = 'semua';
  final _cari = TextEditingController();

  /// Hasil filter teks (nama, NIS, kelas, ujian) atas data yang sudah
  /// difilter sebelumnya oleh status/jurusan/kelas.
  List<Map<String, dynamic>> get _tampil {
    final q = _cari.text.trim().toLowerCase();
    if (q.isEmpty) return _rows;
    return _rows.where((p) {
      final s = p['siswa'];
      final u = p['ujian'];
      final k = s is Map ? s['kelas'] : null;
      return '${s is Map ? s['nama'] : ''} ${s is Map ? s['nis'] : ''} '
              '${k is Map ? k['nama'] : ''} ${u is Map ? u['nama'] : ''} ${p['status'] ?? ''}'
          .toLowerCase()
          .contains(q);
    }).toList();
  }
  String? _selectedJurusanId;
  String? _selectedKelasId;

  @override
  void initState() {
    super.initState();
    _loadRefs();
    _load();
  }

  Future<void> _loadRefs() async {
    try {
      final j = await Api.client
          .from('jurusan')
          .select('id,nama,singkatan')
          .order('nama');
      final k = await Api.client
          .from('kelas')
          .select('id,nama,jurusan_id')
          .order('nama');
      if (!mounted) return;
      setState(() {
        _jurusanList = List<Map<String, dynamic>>.from(j);
        _kelasList = List<Map<String, dynamic>>.from(k);
      });
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var query = Api.client
          .from('peserta_ujian')
          .select(
              '*,ujian!inner(nama,status),siswa!inner(nama,nis,kelas_id,kelas(nama,jurusan(nama,singkatan)))');

      if (_filterStatus != 'semua') {
        query = query.eq('status', _filterStatus);
      }

      final rows = await query.order('created_at', ascending: false);
      if (!mounted) return;

      List<Map<String, dynamic>> filtered =
          List<Map<String, dynamic>>.from(rows);

      // Filter kelas
      if (_selectedKelasId != null && _selectedKelasId!.isNotEmpty) {
        filtered = filtered
            .where((p) => p['siswa'] is Map &&
                ((p['siswa'] as Map)['kelas_id'] == _selectedKelasId))
            .toList();
      }

      // Filter jurusan (client-side, kelas -> jurusan)
      if (_selectedJurusanId != null && _selectedJurusanId!.isNotEmpty) {
        final kelasIds = _kelasList
            .where((k) => k['jurusan_id'] == _selectedJurusanId)
            .map((k) => k['id'])
            .toSet();
        filtered = filtered
            .where((p) =>
                p['siswa'] is Map &&
                kelasIds.contains((p['siswa'] as Map)['kelas_id']))
            .toList();
      }

      setState(() {
        _rows = filtered;
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
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _cari,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Cari nama siswa, NIS, kelas, atau ujian…',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedJurusanId,
                    decoration: const InputDecoration(
                      labelText: 'Jurusan',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text('Semua Jurusan')),
                      ..._jurusanList.map((j) => DropdownMenuItem<String>(
                            value: j['id'] as String?,
                            child: Text(j['nama']?.toString() ?? ''),
                          )),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _selectedJurusanId = v;
                        _selectedKelasId = null;
                      });
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedKelasId,
                    decoration: const InputDecoration(
                      labelText: 'Kelas',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text('Semua Kelas')),
                      ..._kelasList
                          .where((k) =>
                              _selectedJurusanId == null ||
                              k['jurusan_id'] == _selectedJurusanId)
                          .map((k) => DropdownMenuItem<String>(
                                value: k['id'] as String?,
                                child: Text(k['nama']?.toString() ?? ''),
                              )),
                    ],
                    onChanged: (v) {
                      setState(() => _selectedKelasId = v);
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _filterStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'semua', child: Text('Semua')),
                      DropdownMenuItem(value: 'belum', child: Text('Belum')),
                      DropdownMenuItem(
                          value: 'mengikuti', child: Text('Mengerjakan')),
                      DropdownMenuItem(
                          value: 'selesai', child: Text('Selesai')),
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
    if (_tampil.isEmpty && _cari.text.trim().isNotEmpty) {
      return const Center(child: Text('Tidak ada peserta yang cocok.',
          style: TextStyle(color: Colors.grey)));
    }
    if (_rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                'Belum ada peserta yang terdaftar',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Peserta muncul setelah ujian dibuat & siswa di-pairing.\n\n'
                'Gunakan filter di atas (jurusan & kelas) untuk melihat bagian tertentu.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _tampil.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final p = _tampil[i];
          final siswa = p['siswa'];
          final ujian = p['ujian'];
          final kelasMap =
              (siswa is Map && siswa['kelas'] is Map) ? siswa['kelas'] : {};
          final kelas = kelasMap['nama'] as String?;
          final jurusanMap = (kelasMap['jurusan'] is Map)
              ? kelasMap['jurusan']
              : {};
          final jurusan = jurusanMap['nama'] as String?;
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _statusColor(p['status']),
                child: Text(
                  (p['status'] ?? '?')[0].toString().toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(siswa is Map ? siswa['nama'] ?? '' : '',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  'NIS: ${siswa is Map ? siswa['nis'] ?? '-' : '-'}\n'
                  'Kelas: ${kelas ?? '-'}'
                  '${jurusan != null ? ' • $jurusan' : ''}\n'
                  'Ujian: ${ujian is Map ? ujian['nama'] ?? '-' : '-'}'),
              trailing: Chip(
                label: Text((p['status'] ?? '').toString().toUpperCase(),
                    style: const TextStyle(fontSize: 10)),
                backgroundColor:
                    _statusColor(p['status']).withValues(alpha: 0.15),
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