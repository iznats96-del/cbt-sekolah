import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../../widgets/crud_screen.dart';

class UjianFormScreen extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final String? ujianId;
  const UjianFormScreen({super.key, this.initial, this.ujianId});

  @override
  State<UjianFormScreen> createState() => _UjianFormScreenState();
}

class _UjianFormScreenState extends State<UjianFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaCtrl = TextEditingController();
  final _menitCtrl = TextEditingController(text: '90');
  final _catatanCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();

  String? _jenisUjianId, _mapelId, _kelasId, _sesiId;
  String? _tanggal;
  TimeOfDay? _jamMulai;
  TimeOfDay? _jamSelesai;
  List<String> _selectedSoal = [];
  bool _statusAktif = false;
  bool _loading = false;

  List<DropdownItem> _mapelOpt = [], _kelasOpt = [], _jenisOpt = [], _sesiOpt = [];
  List<Map<String, dynamic>> _bankSoal = [];

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      _namaCtrl.text = init['nama']?.toString() ?? '';
      _menitCtrl.text = '${init['alokasi_menit'] ?? 90}';
      _catatanCtrl.text = init['catatan']?.toString() ?? '';
      _tokenCtrl.text = init['token']?.toString() ?? '';
      _jenisUjianId = init['jenis_ujian_id']?.toString();
      _mapelId = init['mapel_id']?.toString();
      _kelasId = init['kelas_id']?.toString();
      _sesiId = init['sesi_id']?.toString();
      _tanggal = init['tanggal']?.toString().split('T').first;
      _jamMulai = _timeFromIso(init['waktu_mulai']?.toString());
      _jamSelesai = _timeFromIso(init['waktu_selesai']?.toString());
      final sl = init['soal_list'];
      if (sl is List) _selectedSoal = sl.map((e) => e.toString()).toList();
      _statusAktif = init['status'] == 'aktif';
    } else {
      _tokenCtrl.text = _genToken();
    }
    _loadOptions();
    _loadBankSoal();
  }

  String _genToken() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  String _fmtTod(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  TimeOfDay? _timeFromIso(String? iso) {
    final d = DateTime.tryParse(iso ?? '');
    if (d == null) return null;
    final l = d.toLocal();
    return TimeOfDay(hour: l.hour, minute: l.minute);
  }

  Future<void> _pickJam(bool mulai) async {
    final t = await showTimePicker(
      context: context,
      initialTime: (mulai ? _jamMulai : _jamSelesai) ?? const TimeOfDay(hour: 7, minute: 30),
    );
    if (t != null) setState(() => mulai ? _jamMulai = t : _jamSelesai = t);
  }

  Future<void> _loadOptions() async {
    try {
      final r = await Future.wait([
        fetchDropdown('mata_pelajaran', 'nama', 'id'),
        fetchDropdown('kelas', 'nama', 'id'),
        fetchDropdown('jenis_ujian', 'nama', 'id'),
        fetchDropdown('sesi', 'nama', 'id'),
      ]);
      if (!mounted) return;
      setState(() {
        _mapelOpt = r[0];
        _kelasOpt = r[1];
        _jenisOpt = r[2];
        _sesiOpt = r[3];
      });
    } catch (e) {
      if (mounted) _snack('Gagal muat opsi: $e', error: true);
    }
  }

  Future<void> _loadBankSoal() async {
    try {
      final rows = await Api.client
          .from('bank_soal')
          .select('id,soal,jenis,bobot,mata_pelajaran(nama)')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() => _bankSoal = List<Map<String, dynamic>>.from(rows));
    } catch (_) {}
  }

  Future<void> _pickSoal() async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => SoalPickerDialog(
        allSoal: _bankSoal,
        selected: _selectedSoal,
      ),
    );
    if (result != null) setState(() => _selectedSoal = result);
  }

  String? _gabung(String? tgl, TimeOfDay? t) {
    if (tgl == null || t == null) return null;
    final d = DateTime.tryParse('${tgl}T00:00:00');
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute).toUtc().toIso8601String();
  }

  Future<void> _pickTanggal() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year, now.month, now.day),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _tanggal =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_mapelId == null) return _err('Pilih mata pelajaran');
    if (_kelasId == null) return _err('Pilih kelas');
    if (_jenisUjianId == null) return _err('Pilih jenis ujian');
    if (_tanggal == null) return _err('Pilih tanggal ujian');
    if (_selectedSoal.isEmpty) return _err('Pilih minimal 1 soal');

    setState(() => _loading = true);
    try {
      final data = <String, dynamic>{
        'nama': _namaCtrl.text.trim(),
        'jenis_ujian_id': _jenisUjianId,
        'mapel_id': _mapelId,
        'kelas_id': _kelasId,
        'guru_id': Api.user?.id,
        'tanggal': _tanggal,
        'sesi_id': _sesiId,
        'alokasi_menit': num.tryParse(_menitCtrl.text.trim()) ?? 90,
        'token': _tokenCtrl.text.trim().isEmpty ? _genToken() : _tokenCtrl.text.trim(),
        'soal_list': _selectedSoal,
        'catatan': _catatanCtrl.text.trim().isEmpty ? null : _catatanCtrl.text.trim(),
        'waktu_mulai': _gabung(_tanggal, _jamMulai),
        'waktu_selesai': _gabung(_tanggal, _jamSelesai),
      };
      if (widget.ujianId != null) {
        await Api.client.from('ujian').update(data).eq('id', widget.ujianId!);
      } else {
        await Api.client.from('ujian').insert(data);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Gagal: $e', error: true);
    }
  }

  void _err(String m) => _snack(m, error: true);
  void _snack(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), backgroundColor: error ? AppTheme.danger : null));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: Text(widget.initial == null ? 'Buat Ujian' : 'Edit Ujian')),
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
                    TextFormField(
                      controller: _namaCtrl,
                      decoration: const InputDecoration(labelText: 'Nama Ujian *'),
                      validator: (v) => v == null || v.isEmpty ? 'Isi nama ujian' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _jenisUjianId,
                      decoration: const InputDecoration(labelText: 'Jenis Ujian *'),
                      items: [const DropdownMenuItem(value: null, child: Text('— pilih —')), ..._jenisOpt
                          .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label)))],
                      onChanged: (v) => setState(() => _jenisUjianId = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _mapelId,
                      decoration: const InputDecoration(labelText: 'Mata Pelajaran *'),
                      items: [const DropdownMenuItem(value: null, child: Text('— pilih —')), ..._mapelOpt
                          .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label)))],
                      onChanged: (v) => setState(() => _mapelId = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _kelasId,
                      decoration: const InputDecoration(labelText: 'Kelas *'),
                      items: [const DropdownMenuItem(value: null, child: Text('— pilih —')), ..._kelasOpt
                          .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label)))],
                      onChanged: (v) => setState(() => _kelasId = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _sesiId,
                      decoration: const InputDecoration(labelText: 'Sesi (opsional)'),
                      items: [const DropdownMenuItem(value: null, child: Text('— tidak ada —')), ..._sesiOpt
                          .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label)))],
                      onChanged: (v) => setState(() => _sesiId = v),
                    ),
                    const SizedBox(height: 12),
                    // tanggal
                    TextFormField(
                      readOnly: true,
                      controller: TextEditingController(
                          text: _tanggal ?? ''),
                      onTap: _pickTanggal,
                      decoration: const InputDecoration(labelText: 'Tanggal Ujian *'),
                    ),
                    const SizedBox(height: 12),
                                        const SizedBox(height: 12),
                    // ── Jendela jam ujian (sesuai jadwal pelajaran) ──
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF3FB),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('JAM AKSES (kosongkan = bebas dalam status aktif)',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: AppTheme.primary),
                                  onPressed: () => _pickJam(true),
                                  icon: const Icon(Icons.schedule, size: 18),
                                  label: Text('Mulai '
                                      '${_jamMulai != null ? _fmtTod(_jamMulai!) : '—'}'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: AppTheme.danger),
                                  onPressed: () => _pickJam(false),
                                  icon: const Icon(Icons.event_busy, size: 18),
                                  label: Text('Selesai '
                                      '${_jamSelesai != null ? _fmtTod(_jamSelesai!) : '—'}'),
                                ),
                              ),
                            ],
                          ),
                          if (_jamMulai != null && _jamSelesai != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                  'Siswa hanya bisa masuk & mengerjakan pk ${_fmtTod(_jamMulai!)} – ${_fmtTod(_jamSelesai!)}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _menitCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Alokasi (menit)'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _tokenCtrl,
                            decoration: const InputDecoration(labelText: 'Token'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _catatanCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Soal Ujian', style: TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text('${_selectedSoal.length} soal dipilih',
                            style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _pickSoal,
                      icon: const Icon(Icons.library_add),
                      label: const Text('Pilih Soal dari Bank'),
                    ),
                    if (_selectedSoal.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      for (final sid in _selectedSoal)
                        Builder(builder: (context) {
                          final so = _bankSoal.where((s) => s['id'].toString() == sid).firstOrNull;
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.description_outlined, size: 20),
                            title: Text(
                              (so?['soal'] ?? '').toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => setState(() => _selectedSoal.remove(sid)),
                            ),
                          );
                        }),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Simpan Ujian'),
            ),
          ],
        ),
      ),
    );
  }
}

class SoalPickerDialog extends StatefulWidget {
  final List<Map<String, dynamic>> allSoal;
  final List<String> selected;
  const SoalPickerDialog({required this.allSoal, required this.selected});

  @override
  State<SoalPickerDialog> createState() => SoalPickerDialogState();
}

class SoalPickerDialogState extends State<SoalPickerDialog> {
  late final Set<String> _sel = widget.selected.toSet();
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _q.trim().isEmpty
        ? widget.allSoal
        : widget.allSoal
            .where((s) => s['soal'].toString().toLowerCase().contains(_q.trim().toLowerCase()))
            .toList();
    return AlertDialog(
      title: const Text('Pilih Soal'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(hintText: 'Cari soal...', prefixIcon: Icon(Icons.search)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Tidak ada soal'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (c, i) {
                        final s = filtered[i];
                        final id = s['id'].toString();
                        final checked = _sel.contains(id);
                        return CheckboxListTile(
                          value: checked,
                          title: Text(s['soal'].toString(),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${s['jenis']} • bobot ${s['bobot']}'),
                          onChanged: (_) => setState(() {
                            if (checked) {
                              _sel.remove(id);
                            } else {
                              _sel.add(id);
                            }
                          }),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _sel.toList()),
          child: Text('Pilih (${_sel.length})'),
        ),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}