import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show File, FileMode;
import 'dart:convert' show utf8;
import 'dart:typed_data' show Uint8List;

import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../../widgets/state_views.dart';
import '../../widgets/dashboard_header.dart';

class DaftarAkunScreen extends StatefulWidget {
  const DaftarAkunScreen({super.key});

  @override
  State<DaftarAkunScreen> createState() => _DaftarAkunScreenState();
}

class _DaftarAkunScreenState extends State<DaftarAkunScreen> {
  List<dynamic> _rows = [];
  bool _loading = true;
  String? _error;
  String _q = '';
  String _filterKelas = '';

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
      final rows = await Api.client.rpc('admin_daftar_akun_siswa');
      if (!mounted) return;
      setState(() {
        _rows = List<dynamic>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat: $e';
        _loading = false;
      });
    }
  }

  List<String> get kelasList {
    final s = <String>{for (final r in _rows) '${r['kelas'] ?? '(tanpa kelas)'}'};
    return s.toList()..sort();
  }

  List<dynamic> get _shown {
    return _rows.where((r) {
      if (_filterKelas.isNotEmpty &&
          '${r['kelas'] ?? ''}' != _filterKelas) return false;
      if (_q.isNotEmpty) {
        final t =
            '${r['nama']} ${r['nis']} ${r['pw'] ?? ''}'.toLowerCase();
        if (!t.contains(_q.toLowerCase())) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _resetSemua() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reset SEMUA password siswa?'),
        content: const Text(
            'Setiap siswa akan dapat password baru acak 79xxxx (login tetap pakai NIS).\n'
            'Password lama MATI. Setelah ini: cetak/salin Daftar Akun dan bagikan lewat wali kelas.',
            style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Reset Sekarang')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await Api.client.rpc('admin_reset_semua_password',
          params: {'p_kelas_id': null});
      final m = res is Map ? Map<String, dynamic>.from(res) : {};
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${m['direset'] ?? 0} password direset — bagikan daftar baru'),
          backgroundColor: AppTheme.secondary));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: AppTheme.danger));
    }
  }

  String _formatDaftar(String kelas, List<dynamic> baris) {
    final buf = StringBuffer()
      ..writeln('Daftar Akun Kelas $kelas')
      ..writeln();
    for (final r in baris) {
      buf
        ..writeln('Nama: ${r['nama'] ?? '-'}')
        ..writeln('Nis: ${r['nis'] ?? '-'} - password: ${r['pw'] ?? '(belum tercatat)'}')
        ..writeln();
    }
    return buf.toString().trimRight();
  }

  Future<void> _salinSemua() async {
    final groups = <String, List<dynamic>>{};
    final urutan = <String>[];
    for (final r in _shown) {
      final k = '${r['kelas'] ?? '(tanpa kelas)'}';
      if (!groups.containsKey(k)) {
        groups[k] = <dynamic>[];
        urutan.add(k);
      }
      groups[k]!.add(r);
    }
    final buf = StringBuffer();
    for (final k in urutan) {
      if (buf.isNotEmpty) buf.writeln();
      buf.writeln(_formatDaftar(k, groups[k]!));
    }
    await Clipboard.setData(ClipboardData(text: buf.toString().trimRight()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Daftar ${_rows.length} akun tersalin ke clipboard'),
            backgroundColor: AppTheme.secondary));
  }

  /// Salin daftar khusus rombel terpilih (untuk wali kelas/cetak per kelas).
  Future<void> _salinPerKelas(String kelas) async {
    final baris = _shown.where((r) => '${r['kelas']}' == kelas).toList();
    if (baris.isEmpty) return;
    await Clipboard.setData(
        ClipboardData(text: _formatDaftar(kelas, baris)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Daftar rombel $kelas tersalin (${baris.length} siswa)'),
            backgroundColor: AppTheme.secondary));
  }

  /// Export CSV daftar akun per kelas (atau semua) — download file.
  Future<void> _exportPerKelas(String kelas) async {
    final baris = kelas == 'semua'
        ? _shown
        : _shown.where((r) => '${r['kelas']}' == kelas).toList();
    if (baris.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Data kosong')));
      return;
    }
    final buf = StringBuffer('Nomor;NIS;Nama;Kelas;Password Login\n');
    for (final r in baris) {
      final nama = '${r['nama']}'
          .replaceAll(RegExp(r'[";\n]'), ' ');
      buf.writeln('${r['nomor'] ?? '-'};${r['nis']};$nama;${r['kelas'] ?? '-'};${r['pw'] ?? '(belum tercatat)'}');
    }
    final uri = await FilePicker.saveFile(
      dialogTitle: 'Export daftar akun',
      fileName:
          'daftar_akun_${kelas == 'semua' ? 'semua' : kelas.replaceAll(RegExp(r'\s+'), '_')}.csv',
      bytes: Uint8List.fromList(utf8.encode(buf.toString())),
      allowedExtensions: const ['csv'],
      mimeType: 'text/csv',
    );
    if (uri == null || !mounted) return;
    try {
      final f = File.fromUri(uri);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Tersimpan: ${uri.path} (${baris.length} siswa)'),
          backgroundColor: AppTheme.secondary));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: DashboardHeader(
        title: 'DAFTAR AKUN SISWA',
        subtitle: 'Username, password & nomor peserta',
        stats: [('siswa', '${_rows.length}')],
        actions: [
          IconButton(
              tooltip: 'Salin semua',
              icon: const Icon(Icons.copy_all_outlined, color: Colors.white),
              onPressed: _salinSemua),
          IconButton(
              tooltip: 'Reset semua password (79xxxx baru)',
              icon: const Icon(Icons.admin_panel_settings_outlined,
                  color: Colors.white),
              onPressed: _resetSemua),
          PopupMenuButton<String>(
            tooltip: 'Export per kelas',
            icon: const Icon(Icons.file_download_outlined, color: Colors.white),
            onSelected: (v) => _exportPerKelas(v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'semua', child: Text('Semua kelas (gabungan)')),
              ...kelasList.map((k) => PopupMenuItem(value: k, child: Text(k))),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _rows.isEmpty
                  ? const Center(
                      child: Text('Belum ada akun siswa terdaftar',
                          style: TextStyle(color: Colors.grey)))
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  onChanged: (v) => setState(() => _q = v),
                                  decoration: const InputDecoration(
                                    hintText: 'cari nama/nis/password...',
                                    isDense: true,
                                    prefixIcon:
                                        Icon(Icons.search, size: 18),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 150,
                                child: DropdownButtonFormField<String?>(
                                  borderRadius: BorderRadius.circular(10),
                                  initialValue:
                                      _filterKelas.isEmpty ? null : _filterKelas,
                                  hint: const Text('semua rombel',
                                      style: TextStyle(fontSize: 11.5)),
                                  items: [
                                    const DropdownMenuItem(
                                        value: null,
                                        child: Text('semua rombel',
                                            style:
                                                TextStyle(fontSize: 11.5))),
                                    ...kelasList.map((k) => DropdownMenuItem(
                                        value: k,
                                        child: Text(k,
                                            style:
                                                TextStyle(fontSize: 11.5)))),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _filterKelas = v ?? ''),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SelectionArea(
                            child: ListView(
                              padding: const EdgeInsets.all(12),
                              children: [
                                Text('Login siswa: NIS + password sesuai tabel. ',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.grey[700])),
                                const SizedBox(height: 8),
                                ..._buildGroups(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }

  List<Widget> _buildGroups() {
    final out = <Widget>[];
    String? lastK;
    for (final r in _shown) {
      final k = '${r['kelas'] ?? '(tanpa kelas)'}';
      if (k != lastK) {
        lastK = k;
        out.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text('ROMBEL $k',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary)),
              ),
              IconButton(
                icon: const Icon(Icons.copy_outlined, size: 16),
                tooltip: 'Salin daftar rombel ini',
                onPressed: () => _salinPerKelas(k),
              ),
            ],
          ),
        ));
        out.add(Container(
            height: 1, color: Colors.grey.shade200));
      }
      out.add(Container(
        margin: const EdgeInsets.only(bottom: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E3A8A).withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ListTile(
          dense: true,
          title: Text('${r['nama']}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text(
              '${r['nomor'] ?? '—'}  •  NIS  ${r['nis']}  •  login: ${r['nis']}@cbt.local',
              style: const TextStyle(
                  fontSize: 11, fontFeatures: [FontFeature.tabularFigures()])),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8)),
            child: Text('${r['pw'] ?? '—'}',
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    fontFeatures: [FontFeature.tabularFigures()])),
          ),
        ),
      ));
    }
    return out;
  }
}
