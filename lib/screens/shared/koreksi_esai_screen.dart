import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';

/// Koreksi jawaban essay (esai) utk satu ujian — guru/admin.
/// 0..10 per butir, simpan per peserta -> nilai akhir terhitung ulang.
class KoreksiEsaiScreen extends StatefulWidget {
  final Map<String, dynamic> ujian;
  const KoreksiEsaiScreen({super.key, required this.ujian});

  @override
  State<KoreksiEsaiScreen> createState() => _KoreksiEsaiScreenState();
}

class _KoreksiEsaiScreenState extends State<KoreksiEsaiScreen> {
  List<Map<String, dynamic>> _peserta = [];
  List<String> _essayIds = [];
  Map<String, String> _namaSiswa = {};
  bool _loading = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final ps = await Api.client
          .from('peserta_ujian')
          .select('id,status,siswa_id,finished_at,nomor_peserta,siswa(nama,nis)')
          .eq('ujian_id', widget.ujian['id'])
          .eq('status', 'selesai')
          .order('finished_at', ascending: true);
      // soal esai
      final essays = await Api.client
          .from('bank_soal')
          .select('id,soal,bobot')
          .eq('jenis', 'essay')
          .inFilter('id', (widget.ujian['soal_list'] as List?) ?? []);
      setState(() {
        _peserta = List<Map<String, dynamic>>.from(ps);
        _essayIds = essays.map((e) => '${(e as Map)['id']}').toList();
        for (final p in _peserta) {
          final s = p['siswa'];
          if (s is Map) _namaSiswa['${p['siswa_id']}'] = '${s['nama']}';
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: Text('Koreksi Esai — ${widget.ujian['nama']}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err != null
              ? Center(child: Text(_err!))
              : _peserta.isEmpty
                  ? const Center(child: Text('Belum ada peserta yang mengumpulkan'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _peserta.length,
                      itemBuilder: (c, i) {
                        final p = _peserta[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: CircleAvatar(child: Text('${i + 1}')),
                            title: Text(
                                '${_namaSiswa['${p['siswa_id']}'] ?? '?'}  •  ${p['nomor_peserta'] ?? 'tanpa nomor'}'),
                            subtitle: Text('selesai ${p['finished_at']}'),
                            trailing: const Icon(Icons.edit_note),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => _SatuPesertaEsai(
                                    ujian: widget.ujian,
                                    peserta: p,
                                    essayIds: _essayIds))),
                          ),
                        );
                      },
                    ),
    );
  }
}

class _SatuPesertaEsai extends StatefulWidget {
  final Map<String, dynamic> ujian;
  final Map<String, dynamic> peserta;
  final List<String> essayIds;
  const _SatuPesertaEsai(
      {required this.ujian, required this.peserta, required this.essayIds});

  @override
  State<_SatuPesertaEsai> createState() => _SatuPesertaEsaiState();
}

class _SatuPesertaEsaiState extends State<_SatuPesertaEsai> {
  List<Map<String, dynamic>> _soal = [];
  Map<String, Map<String, dynamic>> _jwbnBySoal = {};
  final Map<String, TextEditingController> _nilai = {};
  bool _loading = true;
  bool _saving = false;
  String? _err;
  double? _finalNilai;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.essayIds.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final soal = await Api.client
          .from('bank_soal')
          .select('id,soal,bobot')
          .inFilter('id', widget.essayIds);
      final jw = await Api.client
          .from('jawaban_siswa')
          .select('id,soal_id,jawaban,nilai')
          .eq('peserta_ujian_id', widget.peserta['id'])
          .inFilter('soal_id', widget.essayIds);
      for (final j in jw) {
        final m = Map<String, dynamic>.from(j as Map);
        _jwbnBySoal['${m['soal_id']}'] = m;
        final cur = m['nilai'];
        final ctl = TextEditingController(
            text: cur == null ? '' : '${(cur as num).toStringAsFixed(0)}');
        _nilai['${m['soal_id']}'] = ctl;
      }
      setState(() {
        _soal = List<Map<String, dynamic>>.from(soal as List);
        _loading = false;
      });
      _refreshNilai();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _refreshNilai() async {
    try {
      final h = await Api.client
          .from('hasil_ujian')
          .select('nilai')
          .eq('peserta_ujian_id', widget.peserta['id'])
          .limit(1);
      if (h.isNotEmpty && mounted) {
        setState(() => _finalNilai = double.tryParse('${h.first['nilai']}'));
      }
    } catch (_) {}
  }

  Future<void> _simpan() async {
    setState(() => _saving = true);
    String? fail;
    for (final entry in _nilai.entries) {
      final jmap = _jwbnBySoal[entry.key];
      if (jmap == null) continue; // siswa tak jawab -> tak ada baris
      final v = double.tryParse(entry.value.text.trim()) ?? 0;
      try {
        await Api.client.rpc('koreksi_esai',
            params: {'p_jawaban': jmap['id'], 'p_nilai': v});
      } catch (_) {
        fail ??= entry.key;
      }
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(fail == null
            ? 'Nilai esai tersimpan — nilai akhir terhitung ulang ✅'
            : 'Sebagian gagal ($fail) — pastikan login sebagai guru pemilik ujian'),
        backgroundColor: fail == null ? AppTheme.secondary : AppTheme.danger));
    _refreshNilai();
  }

  @override
  void dispose() {
    for (final c in _nilai.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(title: const Text('Koreksi')),
          body: const Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
          title: Text('Esai: ${_namaPeserta()}',
              overflow: TextOverflow.ellipsis),
          actions: [
            if (_finalNilai != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Chip(
                      label: Text('NILAI $_finalNilai',
                          style: const TextStyle(color: Colors.white)),
                      backgroundColor: AppTheme.primary),
                ),
              )
          ]),
      floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppTheme.secondary,
          foregroundColor: Colors.white,
          onPressed: _saving ? null : _simpan,
          icon: _saving
              ? const SizedBox(
                  height: 16, width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check),
          label: const Text('Simpan Nilai')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_err != null) Text(_err!, style: const TextStyle(color: AppTheme.danger)),
          if (_soal.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Ujian ini tidak punya soal esai',
                  textAlign: TextAlign.center),
            ),
          for (final s in _soal)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${s['soal']}',
                        style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(_txtJawaban("${s['id']}"), style: const TextStyle(height: 1.45)),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Nilai 0–10:', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            width: 90,
                            child: TextField(
                              controller: _nilai['${s['id']}'] ??=
                                  TextEditingController(),
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                  isDense: true, hintText: '0'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }


  String _txtJawaban(String sid) {
    final v = _jwbnBySoal[sid];
    if (v == null) return '— (tidak dijawab) —';
    final j = v['jawaban'];
    if (j == null || j.toString().trim().isEmpty) return '— (tidak dijawab) —';
    return j.toString();
  }
  String _namaPeserta() {
    final s = widget.peserta['siswa'];
    if (s is Map) return '${s['nama']}';
    return 'Peserta';
  }
}
