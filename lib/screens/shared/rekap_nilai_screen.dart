import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../../services/file_saver.dart';
import '../../services/nilai_xlsx.dart';
import '../home.dart';
import 'rekap_detail_screen.dart';
import '../../core/design.dart';
import '../../widgets/dashboard_header.dart';

/// Rekap hasil ujian per rombel (X/XI/XII — TKJ / TSM / AKA) — admin & guru.
class RekapNilaiScreen extends StatefulWidget {
  const RekapNilaiScreen({super.key});

  @override
  State<RekapNilaiScreen> createState() => _RekapNilaiScreenState();
}

class _RekapNilaiScreenState extends State<RekapNilaiScreen> {
  List<Map<String, dynamic>> _ujian = [];
  Map<String, dynamic>? _selected;
  List<Map<String, dynamic>> _peserta = [];
  double _kkm = 75;
  bool _loadingUjian = true;
  bool _loadingRekap = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUjian();
  }

  Future<void> _loadUjian() async {
    setState(() {
      _loadingUjian = true;
      _error = null;
    });
    try {
      var q = Api.client
          .from('ujian')
          .select(
              '*,mata_pelajaran(nama,kkm),kelas!ujian_kelas_id_fkey(nama),jenis_ujian(nama)');
      if (Api.role == 'guru') {
        q = q.eq('guru_id', Api.user?.id ?? '');
      }
      final rows = await q.order('tanggal', ascending: false);
      if (!mounted) return;
      setState(() {
        _ujian = List<Map<String, dynamic>>.from(rows);
        _loadingUjian = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat ujian: $e';
        _loadingUjian = false;
      });
    }
  }

  Future<void> _pilih(Map<String, dynamic> u) async {
    setState(() {
      _selected = u;
      _peserta = [];
      _loadingRekap = true;
      _error = null;
    });
    final mapel = u['mata_pelajaran'];
    _kkm = mapel is Map && mapel['kkm'] != null
        ? double.tryParse('${mapel['kkm']}') ?? 75
        : 75.0;
    try {
      final rows = await Api.client.from('peserta_ujian').select(
          'id,status,nomor_peserta,finished_at,'
          'siswa!inner(nama,nis,kelas!inner(nama)),'
          'hasil_ujian(nilai,dinilai,pelanggaran)')
        .eq('ujian_id', u['id'])
        .order('id');
      if (!mounted) return;
      final list = List<Map<String, dynamic>>.from(rows)
          .map((r) {
        final m = Map<String, dynamic>.from(r);
        if (m['hasil_ujian'] is List && (m['hasil_ujian'] as List).isNotEmpty) {
          m['hasil_ujian'] = m['hasil_ujian'][0];
        } else if (m['hasil_ujian'] is List) {
          m['hasil_ujian'] = null;
        }
        return m;
      }).toList();
      setState(() {
        _peserta = list;
        _loadingRekap = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat rekap: $e\n(Isi/aktifkan kunci jawaban & kumpulkan peserta dulu)';
        _loadingRekap = false;
      });
    }
  }

  Map<String, List<Map<String, dynamic>>> get _byKelas {
    final out = <String, List<Map<String, dynamic>>>{};
    for (final p in _peserta) {
      final s = p['siswa'];
      final k = s is Map && s['kelas'] is Map
          ? '${(s['kelas'] as Map)['nama'] ?? '(tanpa kelas)'}'
          : '(tanpa kelas)';
      (out[k] = out[k] ?? []).add(p);
    }
    return out;
  }

  double? _nilai(Map<String, dynamic> p) {
    final h = p['hasil_ujian'];
    // Nilai sistem (pg) terhitung otomatis; essay=0 sampai guru nilai manual.
    // Tampilkan angka ini di rekap GURU walau dinilai=false, biar rata-rata gak kosong.
    if (h is Map && h['nilai'] != null) {
      return double.tryParse('${h['nilai']}');
    }
    return null;
  }

  String _tingkatDariUjian(Map<String, dynamic> u) {
    final k = u['kelas'];
    final nama = (k is Map ? '${k['nama'] ?? ''}' : '').toUpperCase();
    if (nama.startsWith('XII')) return 'XII';
    if (nama.startsWith('XI')) return 'XI';
    return 'X';
  }

  Future<void> _exportXlsx() async {
    final u = _selected;
    if (u == null) return;
    var tingkat = _tingkatDariUjian(u);
    var sheets = await NilaiXlsx.sheetNames(tingkat);
    String? sheet = sheets.isNotEmpty ? sheets.first : null;
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setS) {
        return AlertDialog(
          title: const Text('Export Nilai ASTS (XLSX)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: tingkat,
                decoration: const InputDecoration(labelText: 'Tingkat'),
                items: ['X', 'XI', 'XII']
                    .map((t) => DropdownMenuItem(value: t, child: Text('Kelas $t')))
                    .toList(),
                onChanged: (v) async {
                  if (v == null) return;
                  setS(() {
                    tingkat = v;
                    sheet = null;
                  });
                  final s = await NilaiXlsx.sheetNames(v);
                  if (!c.mounted) return;
                  setS(() {
                    sheets = s;
                    sheet = s.isNotEmpty ? s.first : null;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: sheet,
                decoration: const InputDecoration(labelText: 'Sheet / Rombel'),
                items: sheets
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setS(() => sheet = v),
              ),
              const SizedBox(height: 10),
              Text('${_peserta.length} peserta di ujian ini',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Batal')),
            FilledButton(
              onPressed: sheet == null ? null : () => Navigator.pop(c, true),
              child: const Text('Export'),
            ),
          ],
        );
      }),
    );
    if (ok != true || sheet == null || !mounted) return;

    final nilai = <String, num>{};
    for (final p in _peserta) {
      final s = p['siswa'];
      final h = p['hasil_ujian'];
      if (s is Map && h is Map && h['nilai'] != null) {
        final n = num.tryParse('${h['nilai']}');
        if (n != null) nilai['${s['nama']}'] = n;
      }
    }
    final mp = u['mata_pelajaran'];
    final mapel = mp is Map ? '${mp['nama'] ?? ''}' : '';

    try {
      final bytes = await NilaiXlsx.build(
        tingkat: tingkat,
        sheetName: sheet!,
        mapel: mapel,
        nilaiByNama: nilai,
      );
      await saveBytes(bytes, 'NILAI ASTS ${mapel.toUpperCase()} - $sheet.xlsx');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('XLSX siap — semua sheet & format template dipertahankan'),
        backgroundColor: AppTheme.secondary,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal export: $e'),
        backgroundColor: AppTheme.danger,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: DashboardHeader(
        title: 'REKAP NILAI PER ROMBEL',
        showBack: true,
        actions: [
          if (_selected != null)
            IconButton(
              tooltip: 'Export Nilai XLSX',
              icon: const Icon(Icons.file_download_outlined, color: Colors.white),
              onPressed: _exportXlsx,
            ),
          if (!Navigator.of(context).canPop()) const LogoutButton(),
        ],
      ),
      body: Column(
        children: [
          if (_ujian.isNotEmpty && !_loadingUjian) _buildPicker(),
          Expanded(
            child: _loadingUjian || _loadingRekap
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.danger, size: 40),
                      const SizedBox(height: 8),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: _selected != null
                              ? () => _pilih(_selected!)
                              : _loadUjian,
                          child: const Text('Coba Lagi')),
                    ]),
                  ),
                )
              : _selected == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Container(
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: const Color(0xFF1E3A8A).withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(0,8))],
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.assignment_outlined, size: 46, color: Color(0xFF2563EB)),
                              SizedBox(height: 12),
                              Text('Pilih ujian untuk melihat rekap', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF101F3C))),
                              SizedBox(height: 6),
                              Text('Rekap per rombel akan muncul di sini.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFF8A97B1))),
                            ],
                          ),
                        ),
                      ))
                   : _buildRekap(),
          ),
        ],
      ),
    );
  }

  Widget _buildPicker() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Cbt.card(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: DropdownButton<String>(
          isExpanded: true,
          underline: const SizedBox(),
          borderRadius: BorderRadius.circular(14),
          value: _selected?['id']?.toString(),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Cbt.blue),
          hint: const Text('Pilih ujian untuk direkap…',
              style: TextStyle(fontSize: 13, color: Cbt.muted)),
          items: _ujian
              .map((u) => DropdownMenuItem(
                    value: u['id'].toString(),
                    child: Text(
                      '${u['nama']} — '
                      '${u['mata_pelajaran'] is Map ? (u['mata_pelajaran'] as Map)['nama'] ?? '' : ''} • ${u['tanggal']?.toString().split('T').first}',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ))
              .toList(),
          onChanged: (id) {
            final u = _ujian.firstWhere((x) => x['id'].toString() == id);
            _pilih(u);
          },
        ),
      ),
    );
  }

  Widget _buildRekap() {
    final groups = _byKelas;
    if (groups.isEmpty) {
      return const Center(
          child: Text('Belum ada peserta terdaftar pada ujian ini\n(siswa masuk pakai token dulu)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey)));
    }
    final names = groups.keys.toList()..sort();
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3A8A).withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_selected!['nama']}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '${_selected!['mata_pelajaran'] is Map ? (_selected!['mata_pelajaran'] as Map)['nama'] ?? '—' : '—'} • KKM ${_kkm.toStringAsFixed(0)} • ${_peserta.length} peserta',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        for (final k in names) _kelasCard(k, groups[k]!),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _kelasCard(String kelas, List<Map<String, dynamic>> list) {
    final selesai = list.where((p) => p['status'] == 'selesai').toList();
    final nilaiList = selesai
        .map(_nilai)
        .whereType<double>()
        .toList();
    final rata = nilaiList.isEmpty
        ? 0.0
        : nilaiList.reduce((a, b) => a + b) / nilaiList.length;
    final tuntas = nilaiList.where((n) => n >= _kkm).length;
    final pct = nilaiList.isEmpty ? 0 : (tuntas * 100 / nilaiList.length).round();
    final maxN = nilaiList.isEmpty ? null : nilaiList.reduce((a, b) => a > b ? a : b);
    final minN = nilaiList.isEmpty ? null : nilaiList.reduce((a, b) => a < b ? a : b);
    final belum = list
        .where((p) => p['status'] != 'selesai' && p['status'] != 'mengikuti')
        .length;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const Border(),
        title: Row(
          children: [
            Expanded(
              child: Text('Rombel $kelas',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            Text('${list.length} peserta',
                style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _mini('Rata ${rata.toStringAsFixed(1)}',
                  nilaiList.isEmpty ? Colors.grey : AppTheme.primary),
              _mini('$pct% tuntas',
                  pct >= 70 ? AppTheme.secondary : AppTheme.danger),
              _mini('Selesai ${selesai.length}/${list.length}',
                  Colors.grey),
              if (belum > 0) _mini('Belum $belum', Colors.orange),
              if (maxN != null)
                _mini('Maks ${maxN.toStringAsFixed(0)}', Colors.grey),
              if (minN != null)
                _mini('Min ${minN.toStringAsFixed(0)}', Colors.grey),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Column(
              children: [
                for (final s in list)
                  _siswaRow(list.indexOf(s) + 1, s),
                if (nilaiList.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                        'Belum ada nilai keluar — cek: kunci jawaban sudah diisi? peserta sudah kumpul?',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 11.5, color: Colors.grey)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mini(String t, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12)),
      child: Text(t,
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Future<void> _resetPeserta(Map<String, dynamic> p) async {
    final s = p['siswa'] as Map? ?? const {};
    final nama = '${s['nama'] ?? '?'}';
    final pid = '${p['id'] ?? ''}';
    if (pid.isEmpty) return;
    final mode = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Reset: $nama'),
        content: const Text(
            'Pilih jenis reset per murid (bukan reset soal):\n\n'
            '• Ulang = hapus semua jawaban dan nilai, kembalikan ke BELUM (murid bisa masuk lagi dari awal)\n'
            '• Buka = kembalikan ke MENGIKUTI tanpa hapus jawaban (lanjut mengerjakan, timer ikut server)\n'
            '• Hapus pelanggaran = nol-kan pelanggaran saja',
            style: TextStyle(fontSize: 12, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(c, 'hapus_pelanggaran'), child: const Text('Hapus pelanggaran')),
          TextButton(onPressed: () => Navigator.pop(c, 'buka'), child: const Text('Buka')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.pop(c, 'ulang'),
              child: const Text('Ulang')),
        ],
      ),
    );
    if (mode == null) return;
    try {
      await Api.client.rpc('admin_reset_peserta', params: {'p_peserta': pid, 'p_mode': mode});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reset $mode berhasil'), backgroundColor: AppTheme.secondary));
      _pilih(_selected!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal reset: $e'), backgroundColor: AppTheme.danger));
    }
  }

  Widget _siswaRow(int no, Map<String, dynamic> p) {
    final s = (p['siswa'] as Map?) ?? const {};
    final h = (p['hasil_ujian'] as Map?) ;
    final nilai = _nilai(p);
    final status = '${p['status'] ?? 'belum'}';
    final pel = h?['pelanggaran'] is num
        ? (h!['pelanggaran'] as num).toInt()
        : 0;
    final nisTxt = (s['nis'] ?? '').toString();
    final nomorTxt = (p['nomor_peserta'] ?? '').toString();
    final pesertaId = '${p['id'] ?? ''}';
    return InkWell(
      onTap: pesertaId.isEmpty
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RekapDetailScreen(
                    ujian: _selected ?? const {}, pesertaId: pesertaId),
              )),
      child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
              width: 30,
              child: Text('$no',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${s['nama'] ?? '?'}',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
                if (nomorTxt.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(nomorTxt,
                        style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary)),
                  ),
                Text('$nisTxt${nisTxt.isNotEmpty ? ' • ' : ''}${_statusLabel(status)}',
                    style:
                        TextStyle(fontSize: 10.5, color: Colors.grey[600])),
              ],
            ),
          ),
          if (pel > 0)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text('$pel',
                  style:
                      const TextStyle(fontSize: 10.5, color: AppTheme.danger)),
            ),
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: nilai == null
                    ? Colors.grey.withValues(alpha: 0.12)
                    : (nilai >= _kkm ? AppTheme.secondary : AppTheme.danger)
                        .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8)),
            child: Text(
              nilai != null
                  ? nilai.toStringAsFixed(0)
                  : status == 'selesai'
                      ? '…'
                      : '—',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: nilai == null
                      ? Colors.grey
                      : nilai >= _kkm
                          ? AppTheme.secondary
                          : AppTheme.danger),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'reset') _resetPeserta(p);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'reset', child: Text('Reset per murid')),
            ],
            icon: const Icon(Icons.more_vert, size: 16, color: Colors.grey),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      ),
    );
  }

  String _statusLabel(String s) => switch (s) {
        'selesai' => 'selesai',
        'mengikuti' => 'sedang mengerjakan',
        'absen' => 'absen',
        'gagal' => 'tidak selesai',
        _ => 'belum masuk',
      };
}
