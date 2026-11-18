import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../../widgets/crud_screen.dart';
import '../../widgets/dashboard_header.dart';

class SoalFormScreen extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final String? soalId;
  const SoalFormScreen({super.key, this.initial, this.soalId});

  @override
  State<SoalFormScreen> createState() => _SoalFormScreenState();
}

class _SoalFormScreenState extends State<SoalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _soalCtrl = TextEditingController();
  final _pembahasanCtrl = TextEditingController();
  final _bobotCtrl = TextEditingController(text: '1');

  String _jenis = 'pg';
  String? _mapelId;
  String? _kelasId; // kompat lama (1 kelas)
  // Multi-kelas: daftar id kelas yang boleh memakai soal ini.
  List<String> _kelasIds = []; // kosong = global semua kelas
  List<TextEditingController> _opsi = [];
  int? _kunciIdx;
  String _essayKunci = '';
  // jodoh: daftar kiri/kanan + peta index kiri -> index kanan
  List<TextEditingController> _kiri = [];
  List<TextEditingController> _kanan = [];
  Map<int, int> _pasangan = {};

  bool _loading = false;
  List<DropdownItem> _mapelOptions = [];
  List<DropdownItem> _kelasOptions = [];

  String? _gambarUrl;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadMapel();
    _loadKelas();
    final init = widget.initial;
    if (init != null) {
      _jenis = init['jenis']?.toString() ?? 'pg';
      // Jenis yang dikenal: pg, essay, jodoh (menjodohkan).
      if (_jenis != 'pg' && _jenis != 'essay' && _jenis != 'jodoh') _jenis = 'pg';
      _mapelId = init['mapel_id']?.toString();
      _kelasId = init['kelas_id']?.toString();
      final ids = init['kelas_ids'];
      if (ids is List) _kelasIds = ids.map((x) => x.toString()).toList();
      if (_kelasIds.isEmpty && _kelasId != null) _kelasIds = [_kelasId!];
      _soalCtrl.text = init['soal']?.toString() ?? '';
      _pembahasanCtrl.text = init['pembahasan']?.toString() ?? '';
      _bobotCtrl.text = '${init['bobot'] ?? 1}';
      _gambarUrl = init['gambar_url']?.toString();

      // Kunci
      final kunci = init['kunci'];
      if (_jenis == 'pg') {
        final opsi = init['opsi'];
        if (opsi is List) {
          _opsi = opsi.map((o) => TextEditingController(text: o.toString())).toList();
        } else if (opsi is Map) {
          final m = Map<String, dynamic>.from(opsi);
          _opsi = m.entries.map((e) => TextEditingController(text: e.value.toString())).toList();
        }
        if (kunci is Map) _kunciIdx = _parseIndex(kunci);
      } else if (_jenis == 'jodoh') {
        final opsi = init['opsi'];
        if (opsi is Map) {
          final k = opsi['kiri'];
          final v = opsi['kanan'];
          if (k is List) _kiri = k.map((x) => TextEditingController(text: x.toString())).toList();
          if (v is List) _kanan = v.map((x) => TextEditingController(text: x.toString())).toList();
        }
        if (kunci is Map && kunci['map'] != null) {
          dynamic mm = kunci['map'];
          if (mm is String) {
            try { mm = jsonDecode(mm); } catch (_) { mm = null; }
          }
          if (mm is Map) {
            _pasangan = mm.map((key, value) => MapEntry(
              int.tryParse(key.toString()) ?? 0,
              int.tryParse(value.toString()) ?? 0,
            ));
          }
        }
        if (_kiri.isEmpty) _kiri = List.generate(5, (_) => TextEditingController());
        if (_kanan.isEmpty) _kanan = List.generate(5, (_) => TextEditingController());
      } else if (_jenis == 'essay') {
        // Essay kunci: teks biasa (old rows may still hold a JSON map — unwrap it).
        dynamic k = kunci;
        if (k is Map) {
          k = (k['pedoman'] ?? k['kunci'] ?? k.values.firstOrNull ?? '').toString();
        }
        _essayKunci = (k ?? '').toString();
      }
    }
    if (_opsi.isEmpty) _opsi = List.generate(4, (_) => TextEditingController());
  }

  int? _parseIndex(Map kunci) {
    for (final e in kunci.entries) {
      if (e.key.contains('index')) return int.tryParse('${e.value}');
    }
    return null;
  }

  String _charAt(int i) => String.fromCharCode(65 + i);

  Future<void> _loadMapel() async {
    try {
      final options = await fetchDropdown('mata_pelajaran', 'nama', 'id');
      if (!mounted) return;
      setState(() => _mapelOptions = options);
    } catch (_) {}
  }

  Future<void> _loadKelas() async {
    try {
      final rows = await Api.client.from('kelas').select('id,nama').order('nama');
      if (!mounted) return;
      setState(() {
        _kelasOptions = [
          ...(rows as List).map((r) => DropdownItem(
              '${r['id']}', '${r['nama']}')),
        ];
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _soalCtrl.dispose();
    _pembahasanCtrl.dispose();
    _bobotCtrl.dispose();
    for (final o in _opsi) {
      o.dispose();
    }
    super.dispose();
  }

  Future<void> _acakOpsi() async {
    if (_jenis != 'pg' || _opsi.isEmpty) return;
    // Acak teks opsi (biar guru ga harus nulis ulang)
    final textList = _opsi.map((o) => o.text).toList();
    textList.shuffle();
    for (var i = 0; i < _opsi.length; i++) {
      _opsi[i].text = textList[i];
    }
    // Kunci sekarang jadi index baru, biar tetap konsisten
    setState(() {});
    _snack('Opsi diacak, cek ulang kunci jawaban ya');
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_mapelId == null) {
      _snack('Pilih mata pelajaran', error: true);
      return;
    }

    setState(() => _loading = true);
    try {
      Map<String, dynamic> kunci;
      dynamic opsi;

      if (_jenis == 'pg') {
        bool allFilled = true;
        for (final o in _opsi) {
          if (o.text.trim().isEmpty) allFilled = false;
        }
        if (!allFilled) {
          setState(() => _loading = false);
          _snack('Semua opsi PG wajib diisi.', error: true);
          return;
        }
        if (_kunciIdx == null) {
          setState(() => _loading = false);
          _snack('Tandai jawaban benar.', error: true);
          return;
        }

        opsi = [for (final o in _opsi) o.text.trim()];
        kunci = {'index': _kunciIdx, 'jawaban': _opsi[_kunciIdx!].text.trim()};
      } else if (_jenis == 'jodoh') {
        if (_kiri.length < 5 || _kiri.length > 10 ||
            _kanan.length < 5 || _kanan.length > 10) {
          setState(() => _loading = false);
          _snack('Soal menjodohkan wajib 5–10 pasangan (kiri & kanan).',
              error: true);
          return;
        }
        if (_kiri.any((c) => c.text.trim().isEmpty) ||
            _kanan.any((c) => c.text.trim().isEmpty)) {
          setState(() => _loading = false);
          _snack('Semua teks kiri & kanan wajib diisi.', error: true);
          return;
        }
        if (_pasangan.length != _kiri.length) {
          setState(() => _loading = false);
          _snack('Pilih pasangan untuk setiap item di kolom kiri.', error: true);
          return;
        }
        opsi = {
          'kiri': [for (final c in _kiri) c.text.trim()],
          'kanan': [for (final c in _kanan) c.text.trim()],
        };
        kunci = {
          'map': _pasangan.map((k, v) => MapEntry(k.toString(), v.toString())),
        };
      } else {
        if (_essayKunci.trim().isEmpty) {
          setState(() => _loading = false);
          _snack('Isi kata kunci / pedoman jawaban essay.', error: true);
          return;
        }
        opsi = null;
        // Essay kunci: teks biasa (bukan wrapper JSON).
        final t = _essayKunci.trim();
        if (t.startsWith('{')) {
          try {
            final m = jsonDecode(t) as Map;
            kunci = {'pedoman': (m.values.first ?? '').toString()};
          } catch (_) {
            kunci = {'pedoman': t};
          }
        } else {
          kunci = {'pedoman': t};
        }
      }

      final bobot = num.tryParse(_bobotCtrl.text.trim()) ?? 1;
      final data = <String, dynamic>{
        'mapel_id': _mapelId,
        'kelas_id': _kelasIds.isNotEmpty ? _kelasIds.first : _kelasId, // kompat lama
        'kelas_ids': _kelasIds.isEmpty ? null : _kelasIds, // NULL = global
        'jenis': _jenis,
        'soal': _soalCtrl.text.trim(),
        'opsi': opsi,
        'kunci': kunci,
        'bobot': bobot,
        'pembahasan': _pembahasanCtrl.text.trim().isEmpty
            ? null
            : _pembahasanCtrl.text.trim(),
        'gambar_url': _gambarUrl,
      };

      if (widget.soalId == null) data['guru_id'] = Api.user?.id;
      if (widget.soalId != null) {
        await Api.client.from('bank_soal').update(data).eq('id', widget.soalId!);
      } else {
        await Api.client.from('bank_soal').insert(data);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Gagal simpan: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppTheme.danger : null));
  }

  Future<void> _pickGambar() async {
    final files = await FilePicker.pickFiles(
      type: FileType.image,
    );
    if (files.isEmpty) return;
    final f = files.first;
    Uint8List bytes;
    try {
      bytes = await f.readAsBytes();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() => _uploading = true);
    try {
      final ext = (f.extension ?? 'png').toLowerCase();
      final path = 'soal/${DateTime.now().millisecondsSinceEpoch}.${ext == "jpeg" ? "jpg" : ext}';
      await Api.routerStorageUpload(
        'soal',
        path,
        bytes,
        contentType: ext == 'png' ? 'image/png' : ext == 'gif' ? 'image/gif' : 'image/jpeg',
        upsert: true,
      );
      final url = Api.routerStorageGetPublicUrl('soal', path);
      if (!mounted) return;
      setState(() {
        _gambarUrl = url;
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      _snack('Gagal upload gambar: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: DashboardHeader(
        title: widget.initial == null ? 'BUAT SOAL' : 'EDIT SOAL',
        showBack: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Kartu 1: Informasi utama
            _card('Informasi Soal', [
              DropdownButtonFormField<String>(
                initialValue: _mapelOptions.any((o) => o.value == _mapelId) ? _mapelId : null,
                decoration: const InputDecoration(
                  labelText: 'Mata Pelajaran *',
                  prefixIcon: Icon(Icons.menu_book_outlined),
                ),
                items: [const DropdownMenuItem(value: null, child: Text('— pilih —')), ..._mapelOptions
                    .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label)))],
                onChanged: (v) => setState(() => _mapelId = v),
              ),
              const SizedBox(height: 12),
              // Multi-pilih kelas: bisa lebih dari satu, kosong = global.
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                      child: Row(
                        children: const [
                          Icon(Icons.school_outlined, size: 18, color: AppTheme.primary),
                          SizedBox(width: 8),
                          Text('Kelas yang boleh pakai soal ini',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        _kelasIds.isEmpty
                            ? 'Belum dipilih = otomatis dipakai semua kelas.'
                            : '${_kelasIds.length} kelas dipilih.',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('Semua Kelas'),
                          selected: _kelasIds.isEmpty,
                          onSelected: (_) => setState(() => _kelasIds = []),
                        ),
                        ..._kelasOptions.where((o) => o.value != null).map(
                          (o) => FilterChip(
                            label: Text(o.label),
                            selected: _kelasIds.contains(o.value),
                            onSelected: (on) => setState(() {
                              if (on) {
                                if (!_kelasIds.contains(o.value)) _kelasIds.add(o.value!);
                              } else {
                                _kelasIds.remove(o.value);
                              }
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('Jenis Soal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'pg', label: Text('PG'), icon: Icon(Icons.radio_button_checked)),
                  ButtonSegment(value: 'essay', label: Text('Essay'), icon: Icon(Icons.edit_note)),
                  ButtonSegment(value: 'jodoh', label: Text('Jodohkan'), icon: Icon(Icons.link)),
                ],
                selected: {_jenis},
                onSelectionChanged: (s) => setState(() => _jenis = s.first),
              ),
              const SizedBox(height: 16),
              if (_jenis != 'jodoh')
                TextFormField(
                  controller: _soalCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Soal *',
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                  validator: (v) {
                    return (v == null || v.isEmpty) ? 'Isi soal' : null;
                  },
                ),
              if (_jenis == 'jodoh')
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Item di kolom kiri adalah soal. Isi item kiri dan pilihan kanan, lalu tentukan pasangan yang benar.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF17324D)),
                  ),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _pembahasanCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Pembahasan (opsional)',
                  prefixIcon: Icon(Icons.info_outline),
                ),
              ),
              const SizedBox(height: 12),
              // Bobot dihitung OTOMATIS oleh server dari kategori mapel + jenis
              // (instruksi kepsek: PG 60 / Jodoh 20 / Essay 20 = 100).
              // Guru tidak perlu mengisi/manual bobot.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline, size: 18, color: AppTheme.primary),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Bobot nilai dihitung otomatis dari jenis soal & kategori mapel (umum/produktif). Total nilai maksimal 100.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF17324D)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Gambar
              const Text('Gambar Soal (opsional)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _uploading ? null : _pickGambar,
                    icon: _uploading
                        ? const SizedBox(
                            height: 14, width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
                        : const Icon(Icons.image_outlined, size: 18),
                    label: const Text('Pilih Gambar'),
                  ),
                  if (_gambarUrl != null)
                    TextButton(
                      onPressed: () => setState(() => _gambarUrl = null),
                      child: const Text('Hapus', style: TextStyle(color: AppTheme.danger)),
                    ),
                ],
              ),
              if (_gambarUrl != null)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFD0D7DE)),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
                    child: InteractiveViewer(
                      child: Image.network(
                        _gambarUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, e, s) => const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Gambar tidak dapat dimuat',
                              style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),

            // Kartu 2: Sesuai jenis
            if (_jenis == 'pg') ...[
              const SizedBox(height: 12),
              _card('Opsi Jawaban', [
                Row(
                  children: [
                    Text('Tandai jawaban benar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.shuffle_outlined),
                      tooltip: 'Acak teks opsi',
                      onPressed: _acakOpsi,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Tambah opsi',
                      onPressed: _opsi.length < 6
                          ? () => setState(() => _opsi.add(TextEditingController()))
                          : null,
                    ),
                  ],
                ),
                for (var i = 0; i < _opsi.length; i++)
                  Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          String.fromCharCode(65 + i),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _opsi[i],
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _kunciIdx == i
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: _kunciIdx == i ? AppTheme.secondary : Colors.grey,
                        ),
                        tooltip: 'Tandai sebagai jawaban benar',
                        onPressed: () => setState(() => _kunciIdx = i),
                      ),
                    ],
                  ),
                if (_opsi.length > 2)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() => _opsi.removeLast()),
                      child: const Text('Hapus opsi terakhir'),
                    ),
                  ),
              ]),
            ] else if (_jenis == 'jodoh') ...[
              const SizedBox(height: 12),
              _card('Pasangan Jodoh', [
                const Text(
                  'Wajib 5–10 pasangan. Item kiri = soal, pilihan kanan = jawaban. '
                  'Bobot soal dibagi rata ke tiap pasangan.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < _kiri.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        SizedBox(width: 22, child: Text('${i + 1}.', style: const TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(
                          child: TextField(
                            controller: _kiri[i],
                            decoration: InputDecoration(
                              isDense: true,
                              labelText: 'Item kiri ${i + 1}',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(Icons.arrow_right_alt, color: AppTheme.primary),
                        ),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _pasangan[i],
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: 'Pasangan',
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                            ),
                            items: [
                              const DropdownMenuItem<int>(value: null, child: Text('— pilih —')),
                              for (var j = 0; j < _kanan.length; j++)
                                DropdownMenuItem<int>(
                                  value: j,
                                  child: Text(
                                    '${String.fromCharCode(65 + j)}. ${_kanan[j].text.isEmpty ? "(...)" : _kanan[j].text}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (v) => setState(() {
                              if (v == null) _pasangan.remove(i);
                              else _pasangan[i] = v;
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                 TextButton.icon(
                  onPressed: _kiri.length >= 10
                      ? null
                      : () => setState(() => _kiri.add(TextEditingController())),
                  icon: const Icon(Icons.add),
                  label: Text(_kiri.length >= 10
                      ? 'Maksimal 10 pasangan'
                      : 'Tambah pasangan'),
                ),
                const Divider(height: 22),
                const Text('Pilihan kolom kanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                for (var i = 0; i < _kanan.length; i++)
                  Row(
                    children: [
                      SizedBox(width: 22, child: Text('${String.fromCharCode(65 + i)}.', style: const TextStyle(fontWeight: FontWeight.bold))),
                      Expanded(
                        child: TextField(
                          controller: _kanan[i],
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          ),
                        ),
                      ),
                      if (_kanan.length > 2)
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => setState(() {
                            _kanan.removeAt(i);
                            _pasangan.remove(i);
                          }),
                        ),
                    ],
                  ),
                 TextButton.icon(
                  onPressed: _kanan.length >= 10
                      ? null
                      : () => setState(() => _kanan.add(TextEditingController())),
                  icon: const Icon(Icons.add),
                  label: Text(_kanan.length >= 10
                      ? 'Maksimal 10 pilihan'
                      : 'Tambah pilihan kanan'),
                ),
              ]),
            ] else ...[
              const SizedBox(height: 12),
              _card('Kunci Jawaban Essay', [
                TextField(
                  controller: TextEditingController(text: _essayKunci),
                  maxLines: 3,
                  onChanged: (v) => _essayKunci = v,
                  decoration: InputDecoration(
                    labelText: 'Pedoman / kunci jawaban essay',
                    hintText: 'Tulis jawaban/pedoman saja, contoh: fotosintesis',
                    helperText: 'Teks biasa — tidak perlu format JSON.',
                  ),
                ),
              ]),
            ],

            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Simpan Soal'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(String title, List<Widget> children) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
