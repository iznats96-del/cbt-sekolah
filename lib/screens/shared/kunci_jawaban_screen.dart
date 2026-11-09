import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../../widgets/state_views.dart';

/// Editor kunci jawaban per ujian — dipakai GURU (dan admin).
/// - PG   : tap pilihan yang benar -> bank_soal.kunci = {index, jawaban}
/// - Jodoh: tap pasangan benar      -> kunci {index, jawaban} (auto-korel)
/// - Essay: pedoman/kunci teks       -> kunci {pedoman: '...'}
class KunciJawabanScreen extends StatefulWidget {
  final Map<String, dynamic> ujian;
  const KunciJawabanScreen({super.key, required this.ujian});

  @override
  State<KunciJawabanScreen> createState() => _KunciJawabanScreenState();
}

class _KunciJawabanScreenState extends State<KunciJawabanScreen> {
  List<Map<String, dynamic>> _soal = [];
  final Map<String, int> _pilihIdx = {}; // soal id -> index opsi (PG)
  final Map<String, Map<String, int>> _kunciJodoh = {}; // soal id -> {A: idxB}
  final Map<String, String> _essay = {}; // soal id -> teks pedoman
  final Set<String> _dirty = {};
  bool _loading = true;
  bool _saving = false;
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
      final ids = (widget.ujian['soal_list'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      if (ids.isEmpty) {
        setState(() {
          _soal = [];
          _loading = false;
        });
        return;
      }
      final rows = await Api.client
          .from('bank_soal')
          .select('id,jenis,soal,opsi,kunci')
          .inFilter('id', ids);
      final m = <String, Map<String, dynamic>>{
        for (final r in (rows as List)) r['id'].toString(): Map<String, dynamic>.from(r)
      };
      final ordered = [for (final id in ids) if (m[id] != null) m[id]!];
      for (final s in ordered) {
        final k = s['kunci'];
        final jenis = s['jenis']?.toString();
        if (k is Map) {
          if (jenis == 'jodoh') {
            // Kunci jodoh: {0: idxB, 1: idxB, ...} atau legacy {'A': idxB} atau {index: n}
            final mm = <String, int>{};
            for (final e in k.entries) {
              final key = e.key.toString();
              final v = int.tryParse('${e.value}');
              if (v == null) continue;
              mm[key] = v;
            }
            // legacy PG-like: {index: n, jawaban: ...}
            if (mm.isEmpty && k.containsKey('index')) {
              final n = int.tryParse('${k['index']}');
              if (n != null) mm['0'] = n;
            }
            _kunciJodoh[s['id'].toString()] = mm;
          } else {
            final idx = k['index'];
            if (idx is int) _pilihIdx[s['id'].toString()] = idx;
            // Essay: terima 'pedoman' (format baru) maupun 'kunci' (legacy JSON).
            final pedoman =
                (k['pedoman'] ?? k['kunci'] ?? k.values.firstOrNull ?? '').toString();
            if (jenis == 'essay' && pedoman.isNotEmpty) {
              _essay[s['id'].toString()] = pedoman;
            }
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _soal = ordered;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat soal: $e';
        _loading = false;
      });
    }
  }

  int get _pgTotal => _soal.where((s) {
        final j = s['jenis']?.toString();
        return j == 'pg' || j == null;
      }).length;
  int get _pgDone =>
      _soal.where((s) {
        final j = s['jenis']?.toString();
        return (j == 'pg' || j == null) && _pilihIdx[s['id'].toString()] != null;
      }).length;

  Future<void> _save() async {
    if (_dirty.isEmpty) return;
    setState(() => _saving = true);
    try {
      for (final id in _dirty) {
        final s = _soal.firstWhere((e) => e['id'].toString() == id);
        final jenis = s['jenis']?.toString() ?? 'pg';
        Map<String, dynamic> kunci;
        if (jenis == 'essay') {
          kunci = {'pedoman': _essay[id] ?? ''};
        } else if (jenis == 'jodoh') {
          final map = _kunciJodoh[id] ?? {};
          final opsiList = s['opsi'] is List ? List<dynamic>.from(s['opsi'] as List) : <dynamic>[];
          final nPairSafe = (opsiList.length ~/ 2).clamp(1, 10);
          // kunci editor: {0: idxB_baris, ...} (idxB 0-based terhadap baris B).
          // Format simpan: {index: idxB_global_A1, jawaban: teksB} (PG-like, konsisten
          // dgn hitung_nilai: siswa menjawab teks B yang cocok utk A1).
          final a1Pick = (map['0'] ?? 0).clamp(0, nPairSafe - 1);
          final idxBGlobal = a1Pick * 2 + 1;
          kunci = {
            'index': idxBGlobal.clamp(0, opsiList.length - 1),
            'jawaban': (idxBGlobal < opsiList.length) ? opsiList[idxBGlobal].toString() : '',
          };
          // catat pasangan lainnya (A2, A3...) untuk form soal ke depan
          for (final e in map.entries) {
            final ii = int.tryParse(e.key);
            if (ii != null && ii > 0) {
              kunci['$ii'] = (e.value as int).clamp(0, nPairSafe - 1) * 2 + 1;
            }
          }
        } else {
          final idx = _pilihIdx[id];
          final opsi = s['opsi'];
          final list = opsi is List ? opsi : <dynamic>[];
          if (idx == null || idx >= list.length) {
            kunci = {};
          } else {
            kunci = {'index': idx, 'jawaban': list[idx].toString()};
          }
        }
        await Api.client.from('bank_soal').update({'kunci': kunci}).eq('id', id);
      }
      _dirty.clear();
      // hitung ulang nilai utk peserta yang sudah selesai
      int diniliai = 0;
      try {
        final re = await Api.client.rpc('hitung_ujian',
            params: {'p_ujian': widget.ujian['id']});
        diniliai = re is num ? re.toInt() : 0;
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(diniliai > 0
                ? 'Kunci tersimpan — $diniliai peserta dinilai ulang'
                : 'Kunci jawaban tersimpan'),
            backgroundColor: AppTheme.secondary),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal simpan: $e'), backgroundColor: AppTheme.danger),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Editor kunci jodoh: tiap A[i] -> dropdown B yang benar.
  Widget _buildJodohEditor(String id, Map<String, dynamic> s) {
    final opsi = s['opsi'] is List ? List<dynamic>.from(s['opsi'] as List) : <dynamic>[];
    final nPair = (opsi.length ~/ 2).clamp(1, 10);
    final map = _kunciJodoh[id] ?? {};
    if (nPair == 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Jodohkan: B yang benar untuk tiap A', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4338CA))),
          const SizedBox(height: 8),
          for (var i = 0; i < nPair; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text('A${i + 1}. ${i * 2 < opsi.length ? opsi[i * 2].toString() : ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    child: DropdownButton<int>(
                      value: (map['$i'] ?? i).clamp(0, nPair - 1),
                      isDense: true,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      items: List.generate(nPair, (b) => DropdownMenuItem<int>(value: b, child: Text('B${b + 1}. ${i * 2 + 1 < opsi.length ? opsi[i * 2 + 1].toString() : ''}', style: const TextStyle(fontSize: 12)))),
                      onChanged: (v) {
                        if (v == null) return;
                        final mm = Map<String, int>.from(map);
                        mm['$i'] = v;
                        _kunciJodoh[id] = mm;
                        _dirty.add(id);
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Kunci Jawaban'),
        bottom: _soal.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(46),
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: _pgTotal == 0 ? 1 : _pgDone / _pgTotal,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('PG terisi: $_pgDone/$_pgTotal',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
      ),
      floatingActionButton: _soal.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppTheme.secondary,
              foregroundColor: Colors.white,
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(_dirty.isEmpty ? 'Tersimpan' : 'Simpan Kunci (${_dirty.length})'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _soal.isEmpty
                  ? const Center(child: Text('Ujian ini belum punya soal'))
                  : Column(
                      children: [
                        if (widget.ujian['status'] == 'selesai' ||
                            widget.ujian['status'] == 'aktif')
                          Container(
                            width: double.infinity,
                            color: Colors.orange.withValues(alpha: 0.2),
                            padding: const EdgeInsets.all(10),
                            child: Text(
                              widget.ujian['status'] == 'aktif'
                                  ? 'Ujian SEDANG berjalan — simpan kunci sebelum nilai akhir dihitung.'
                                  : 'Ujian sudah selesai. Setelah simpan kunci, minta admin klik "Akhiri & nilai otomatis" ulang atau pakai koreksi manual.',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _soal.length,
                            itemBuilder: (context, i) {
                              final s = _soal[i];
                              final id = s['id'].toString();
                              final jenis = s['jenis']?.toString() ?? 'pg';
                              final opsi = s['opsi'] is List
                                  ? List<String>.from(s['opsi'] as List)
                                  : <String>[];
                              final picked = _pilihIdx[id];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 13,
                                            backgroundColor: picked != null ||
                                                    jenis == 'essay' && _essay[id]?.isNotEmpty == true
                                                ? AppTheme.secondary
                                                : Colors.grey[300],
                                            child: Text('${i + 1}',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white)),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              s['soal']?.toString() ?? '',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  height: 1.4),
                                            ),
                                          ),
                                          if (jenis != 'essay')
                                            Text(jenis == 'jodoh' ? 'JODOH' : 'PG',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: jenis == 'jodoh'
                                                        ? AppTheme.accent
                                                        : AppTheme.primary)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if (jenis == 'essay') ...[
                                        TextField(
                                          maxLines: 3,
                                          controller: TextEditingController(text: _essay[id] ?? ''),
                                          onChanged: (v) {
                                            _essay[id] = v;
                                            _dirty.add(id);
                                          },
                                          decoration: const InputDecoration(
                                              labelText: 'Pedoman / kunci jawaban',
                                              hintText:
                                                  'Jawaban minimal: ... (untuk koreksi manual)'),
                                        ),
                                      ] else if (jenis == 'jodoh') ...[
                                        _buildJodohEditor(id, s),
                                      ] else ...[
                                        for (var o = 0; o < opsi.length; o++)
                                          RadioListTile<int>(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            value: o,
                                            groupValue: picked,
                                            title: Text(
                                              '${String.fromCharCode(65 + o)}. ${opsi[o]}',
                                              style: const TextStyle(fontSize: 13),
                                            ),
                                            activeColor: AppTheme.secondary,
                                            onChanged: (v) {
                                              setState(() {
                                                if (v != null) {
                                                  _pilihIdx[id] = v;
                                                } else {
                                                  _pilihIdx.remove(id);
                                                }
                                                _dirty.add(id);
                                              });
                                            },
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}