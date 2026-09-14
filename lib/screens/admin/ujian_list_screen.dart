import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../../widgets/crud_screen.dart';
import 'import_ujian_screen.dart';
import '../shared/kunci_jawaban_screen.dart';
import 'ujian_form_screen.dart';

class UjianListScreen extends StatefulWidget {
  const UjianListScreen({super.key});

  @override
  State<UjianListScreen> createState() => _UjianListScreenState();
}

class _UjianListScreenState extends State<UjianListScreen> {
  List<Map<String, dynamic>> _ujian = [];
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
          .select(
              '*,mata_pelajaran(nama),kelas(nama),jenis_ujian(nama),sesi(nama)')
          .order('tanggal', ascending: false);
      if (!mounted) return;
      setState(() {
        _ujian = List<Map<String, dynamic>>.from(rows);
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

  Future<void> _add() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const UjianFormScreen()));
    _load();
  }

  Future<void> _edit(Map<String, dynamic> u) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => UjianFormScreen(initial: u, ujianId: u['id'])));
    _load();
  }

  Future<void> _toggleStatus(Map<String, dynamic> u) async {
    final next =
        u['status'] == 'aktif' ? 'selesai' : (u['status'] == 'draft' ? 'aktif' : 'aktif');

    // guard: PG tanpa kunci -> nilai otomatis tidak akan keluar
    String extraWarn = '';
    if (next == 'aktif') {
      try {
        final ids = (u['soal_list'] as List?)?.map((e) => e.toString()).toList() ?? [];
        if (ids.isNotEmpty) {
          final soal = await Api.client
              .from('bank_soal')
              .select('id,jenis,kunci')
              .inFilter('id', ids);
          final tanpaKunci = (soal as List)
              .where((s) => s['jenis'] == 'pg' && (s['kunci'] == null ||
                  (s['kunci'] is Map && !(s['kunci'] as Map).containsKey('jawaban'))))
              .length;
          if (tanpaKunci > 0) {
            extraWarn =
                '\n\n⚠ $tanpaKunci soal PG belum punya KUNCI JAWABAN — nilai otomatis tidak akan benar. Isi kunci dulu lewat menu Soal, atau ujian tetap jalan dengan koreksi manual.';
          }
        }
      } catch (_) {}
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(u['status'] == 'aktif' ? 'Akhiri Ujian?' : 'Aktifkan Ujian?'),
        content: Text((u['status'] == 'aktif'
                ? 'Ujian "aktif" akan berhenti menerima jawaban. Lanjutkan?'
                : 'Ujian akan bisa diakses siswa. Lanjutkan?') +
            extraWarn),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ya')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.client.from('ujian').update({'status': next}).eq('id', u['id']);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: AppTheme.danger));
    }
  }

  Future<void> _publishToken(Map<String, dynamic> u) async {
    final token = u['token']?.toString() ?? '';
    if (token.isEmpty) {
      _snack('Ujian belum punya token.');
      return;
    }
    _snack('Token: $token');
    await showDialog(
      context: context,
      builder: (c) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.key, color: AppTheme.accent, size: 48),
              const SizedBox(height: 12),
              const Text('Token Ujian', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SelectableText(token,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 6)),
              const SizedBox(height: 12),
              const Text('Berikan token ini kepada siswa untuk masuk ujian.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: () => Navigator.pop(c), child: const Text('Tutup')),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: const Text('Jadwal Ujian'), actions: [
        IconButton(
          tooltip: 'Import naskah ujian (.docx)',
          icon: const Icon(Icons.upload_file),
          onPressed: () async {
            final ok = await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ImportUjianScreen()));
            if (ok == true) _load();
          },
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    if (_ujian.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Belum ada jadwal ujian', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            FilledButton(onPressed: _add, child: const Text('+ Buat Ujian')),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _ujian.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _ujianCard(_ujian[i]),
    );
  }

  Widget _ujianCard(Map<String, dynamic> u) {
    final mapel = u['mata_pelajaran'] is Map
        ? (u['mata_pelajaran'] as Map)['nama']?.toString() ?? ''
        : '';
    final kelas = u['kelas'] is Map
        ? (u['kelas'] as Map)['nama']?.toString() ?? ''
        : '';
    final jenis = u['jenis_ujian'] is Map
        ? (u['jenis_ujian'] as Map)['nama']?.toString() ?? ''
        : '';
    final sesi = u['sesi'] is Map ? (u['sesi'] as Map)['nama']?.toString() ?? '' : '';
    final status = u['status']?.toString() ?? 'draft';
    final tgl = u['tanggal']?.toString();
    final d = tgl != null ? tgl.split('T').first : ''; // ambil tanggal saja

    Color statusColor;
    switch (status) {
      case 'aktif':
        statusColor = AppTheme.secondary;
        break;
      case 'selesai':
        statusColor = AppTheme.danger;
        break;
      case 'dibatalkan':
        statusColor = Colors.grey;
        break;
      default:
        statusColor = AppTheme.accent;
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${u['nama'] ?? 'Ujian'}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status.toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (mapel.isNotEmpty)
              _info(Icons.menu_book_outlined, mapel),
            if (kelas.isNotEmpty) _info(Icons.groups_outlined, kelas),
            if (jenis.isNotEmpty) _info(Icons.category_outlined, jenis),
            if (sesi.isNotEmpty) _info(Icons.schedule_outlined, sesi),
            if (d.isNotEmpty) _info(Icons.event_outlined, d),
            _info(Icons.timer_outlined, '${u['alokasi_menit'] ?? 90} menit'),
            if (u['token'] != null) _info(Icons.key, 'Token: ${u['token']}'),
            const Divider(height: 20),
            Row(
              children: [
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _edit(u),
                ),
                IconButton(
                  tooltip: status == 'aktif'
                      ? 'Akhiri & nilai otomatis'
                      : 'Aktifkan ujian',
                  icon: Icon(status == 'aktif'
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outline),
                  onPressed: () => _toggleStatus(u),
                ),
                IconButton(
                  tooltip: 'Isi kunci jawaban',
                  icon: const Icon(Icons.vpn_key_outlined, color: AppTheme.secondary),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => KunciJawabanScreen(ujian: u))),
                ),
                IconButton(
                  tooltip: 'Lihat token',
                  icon: const Icon(Icons.key),
                  onPressed: () => _publishToken(u),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey[800])),
          ),
        ],
      ),
    );
  }
}