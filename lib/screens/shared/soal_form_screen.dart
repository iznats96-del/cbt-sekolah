import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../../widgets/crud_screen.dart';

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
  List<TextEditingController> _opsi = [];
  int? _kunciIdx;
  String _essayKunci = '';

  bool _loading = false;
  List<DropdownItem> _mapelOptions = [];

  String? _gambarUrl;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _loadMapel();
    final init = widget.initial;
    if (init != null) {
      _jenis = init['jenis']?.toString() ?? 'pg';
      _mapelId = init['mapel_id']?.toString();
      _soalCtrl.text = init['soal']?.toString() ?? '';
      _pembahasanCtrl.text = init['pembahasan']?.toString() ?? '';
      _bobotCtrl.text = '${init['bobot'] ?? 1}';
      _gambarUrl = init['gambar_url']?.toString();
      // kunci
      final kunci = init['kunci'];
      if (_jenis == 'pg') {
        final opsi = init['opsi'];
        if (opsi is List) {
          _opsi = opsi
              .map((o) => TextEditingController(text: o.toString()))
              .toList();
        } else if (opsi is Map) {
          final m = Map<String, dynamic>.from(opsi);
          _opsi = m.entries.map((e) => TextEditingController(text: e.value.toString())).toList();
        }
        if (kunci is Map) _kunciIdx = _parseIndex(kunci);
      } else {
        _essayKunci = kunci != null ? jsonEncode(kunci) : '';
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

  Future<void> _loadMapel() async {
    try {
      final options = await fetchDropdown('mata_pelajaran', 'nama', 'id');
      if (!mounted) return;
      setState(() => _mapelOptions = options);
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_mapelId == null) {
      _snack('Pilih mata pelajaran', error: true);
      return;
    }
    if (_jenis == 'pg') {
      bool allFilled = true;
      for (final o in _opsi) {
        if (o.text.trim().isEmpty) allFilled = false;
      }
      if (!allFilled) {
        _snack('Semua opsi PG wajib diisi (kosongkan bila tidak perlu).', error: true);
        return;
      }
      if (_kunciIdx == null) {
        _snack('Tandai jawaban benar pada opsi.', error: true);
        return;
      }
    } else {
      if (_essayKunci.trim().isEmpty) {
        _snack('Isi kata kunci / pedoman jawaban essay.', error: true);
        return;
      }
    }

    setState(() => _loading = true);
    try {
      Map<String, dynamic> kunci;
      dynamic opsi;
      if (_jenis == 'pg') {
        opsi = [for (final o in _opsi) o.text.trim()];
        kunci = {'index': _kunciIdx, 'jawaban': _opsi[_kunciIdx!].text.trim()};
      } else {
        opsi = null;
        kunci = jsonDecode(_essayKunci);
      }

      final bobot = num.tryParse(_bobotCtrl.text.trim()) ?? 1;
      final data = <String, dynamic>{
        'mapel_id': _mapelId,
        'jenis': _jenis,
        'soal': _soalCtrl.text.trim(),
        'opsi': opsi,
        'kunci': kunci,
        'bobot': bobot,
        'pembahasan': _pembahasanCtrl.text.trim().isEmpty
            ? null
            : _pembahasanCtrl.text.trim(),
        'gambar_url': _gambarUrl,
        'guru_id': Api.user?.id,
      };

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
      await Api.client.storage.from('soal').uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(
          contentType: ext == 'png' ? 'image/png' : ext == 'gif' ? 'image/gif' : 'image/jpeg',
          upsert: true,
        ),
      );
      final url = Api.client.storage.from('soal').getPublicUrl(path);
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
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: Text(widget.initial == null ? 'Buat Soal' : 'Edit Soal')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pilih Mata Pelajaran', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _mapelId,
                      decoration: const InputDecoration(labelText: 'Mata Pelajaran *'),
                      items: [const DropdownMenuItem(value: null, child: Text('— pilih —')), ..._mapelOptions
                          .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label)))],
                      onChanged: (v) => setState(() => _mapelId = v),
                    ),
                    const SizedBox(height: 16),
                    const Text('Jenis Soal', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'pg', label: Text('Pilihan Ganda'), icon: Icon(Icons.radio_button_checked)),
                        ButtonSegment(value: 'essay', label: Text('Essay'), icon: Icon(Icons.edit_note)),
                        ButtonSegment(value: 'jodoh', label: Text('Jodohkan'), icon: Icon(Icons.link)),
                      ],
                      selected: {_jenis},
                      onSelectionChanged: (s) => setState(() => _jenis = s.first),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _soalCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Soal *'),
                      validator: (v) => (v == null || v.isEmpty) ? 'Isi soal' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pembahasanCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Pembahasan (opsional)'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _bobotCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Bobot / skor'),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Gambar soal (PNG/JPG)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Gambar Soal (PNG/Foto) — opsional',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _uploading ? null : _pickGambar,
                              icon: _uploading
                                  ? const SizedBox(
                                      height: 14, width: 14,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppTheme.primary))
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
                      ],
                    ),
                  ],
                ),
              ),
            ),

            if (_jenis == 'pg') ...[
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('Opsi Jawaban', style: TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: _opsi.length < 6
                                ? () => setState(() => _opsi.add(TextEditingController()))
                                : null,
                          ),
                        ],
                      ),
                      for (var i = 0; i < _opsi.length; i++)
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _opsi[i],
                                decoration: InputDecoration(
                                  labelText: 'Opsi ${String.fromCharCode(65 + i)}',
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
                            onPressed: _opsi.length > 2
                                ? () => setState(() => _opsi.removeLast())
                                : null,
                            child: const Text('Hapus opsi terakhir'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],

            if (_jenis == 'essay') ...[
              const SizedBox(height: 8),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Kunci Jawaban Essay', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: TextEditingController(text: _essayKunci),
                        maxLines: 3,
                        onChanged: (v) => _essayKunci = v,
                        decoration: const InputDecoration(
                          labelText: 'Pedoman jawaban (JSON)',
                          hintText: '{"kunci": "jawaban", "kunci2": "..."}',
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Format: JSON. Contoh: {"kunci":"fotosintesis"}',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Simpan Soal'),
            ),
          ],
        ),
      ),
    );
  }
}