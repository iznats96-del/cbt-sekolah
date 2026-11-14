import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../../widgets/state_views.dart';
import '../home.dart';
import 'import_ujian_screen.dart';
import '../shared/kunci_jawaban_screen.dart';
import '../shared/rekap_nilai_screen.dart';
import '../shared/koreksi_esai_screen.dart';
import '../shared/cetak_peserta_screen.dart';
import 'daftar_akun_screen.dart';
import 'ujian_form_screen.dart';

class UjianListScreen extends StatefulWidget {
  final bool showLogout;
  const UjianListScreen({super.key, this.showLogout = true});

  @override
  State<UjianListScreen> createState() => _UjianListScreenState();
}

class _UjianListScreenState extends State<UjianListScreen> {
  List<Map<String, dynamic>> _ujian = [];
  bool _loading = true;
  String? _error;
  String _filter = 'semua';
  String _query = '';

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
              '*,mata_pelajaran(nama),kelas!ujian_kelas_id_fkey(nama),jenis_ujian(nama),sesi(nama)')
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
              .where((s) {
                final j = s['jenis'];
                final k = s['kunci'];
                if (j == 'pg') {
                  return (k == null ||
                      (k is Map && !k.containsKey('jawaban')));
                }
                return false;
              })
              .length;
          if (tanpaKunci > 0) {
            extraWarn =
                '\n\n$tanpaKunci soal PG belum punya KUNCI JAWABAN — nilai otomatis tidak akan benar. Isi kunci dulu lewat menu Soal, atau ujian tetap jalan dengan koreksi manual.';
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

  void _snack(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m), backgroundColor: error ? AppTheme.danger : null));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: const Text('Jadwal Ujian'), actions: [
        IconButton(
          tooltip: 'Rekap nilai per rombel',
          icon: const Icon(Icons.insert_chart_outlined),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const RekapNilaiScreen())),
        ),
        IconButton(
          tooltip: 'Import naskah ujian (.docx)',
          icon: const Icon(Icons.upload_file),
          onPressed: () async {
            final ok = await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ImportUjianScreen()));
            if (ok == true) _load();
          },
        ),
        if (widget.showLogout) const LogoutButton(),
      ]),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: ContentMaxWidth(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    if (_ujian.isEmpty) {
      return EmptyState(
        icon: Icons.calendar_today_outlined,
        title: 'Belum ada jadwal ujian',
        subtitle: 'Buat ujian manual atau import naskah DOCX lewat ikon upload.',
        actionLabel: 'Buat Ujian',
        onAction: _add,
      );
    }
    final visible = _ujian.where((u) {
      final status = u['status']?.toString() ?? 'draft';
      final text = '${u['nama'] ?? ''} ${u['mata_pelajaran'] is Map ? (u['mata_pelajaran'] as Map)['nama'] ?? '' : ''}'.toLowerCase();
      return (_filter == 'semua' || status == _filter) &&
          (_query.isEmpty || text.contains(_query.toLowerCase()));
    }).toList();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: const InputDecoration(
              hintText: 'Cari nama ujian atau mapel...',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final item in const [
                ('semua', 'Semua'),
                ('draft', 'Draft'),
                ('aktif', 'Aktif'),
                ('selesai', 'Selesai'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(item.$2),
                    selected: _filter == item.$1,
                    onSelected: (_) => setState(() => _filter = item.$1),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 4),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Tidak ada ujian yang cocok dengan filter.')),
            ),
          for (int i = 0; i < visible.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _ujianCard(visible[i]),
          ],
        ],
      ),
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
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                   child: Text(_statusLabel(status),
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
            _info(Icons.quiz_outlined,
                '${(u['soal_list'] as List?)?.length ?? 0} soal'),
            if (u['waktu_mulai'] != null)
              _info(Icons.schedule,
                  'Jam akses ${_jam(u['waktu_mulai'])} – ${u['waktu_selesai'] != null ? _jam(u['waktu_selesai']) : 'selesai'}'),
            if (u['jadwal_mapel'] is Map)
              _info(Icons.date_range,
                  'Jadwal: '
                  '${_hariNm[((u['jadwal_mapel'] as Map)['hari'] as num?)?.toInt() ?? 0]} '
                  '${_hhmm((u['jadwal_mapel'] as Map)['jam_mulai'])}–'
                  '${_hhmm((u['jadwal_mapel'] as Map)['jam_selesai'])} (hanya buka pada jam itu)'),
            const Divider(height: 20),
            Row(
              children: [
                IconButton(
                  tooltip: 'Edit jadwal/mapel/jam',
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
                PopupMenuButton<String>(
                  tooltip: 'Opsi ujian',
                  onSelected: (v) {
                    switch (v) {
                      case 'soal':
                        _kelolaSoal(u);
                      case 'kunci':
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => KunciJawabanScreen(ujian: u)));
                      case 'esai':
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => KoreksiEsaiScreen(ujian: u)));
                      case 'nomor':
                        _terbitkanNomor(u);
                      case 'cetak':
                        _cetakPeserta(u);
                      case 'duplikat':
                        _duplikatRombel(u);
                      case 'akun':
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const DaftarAkunScreen()));
                      case 'hapus':
                        _hapusUjian(u);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'soal',
                        child: MenuRow(Icons.playlist_add_check, 'Kelola Soal',
                            iconColor: AppTheme.secondary)),
                    const PopupMenuItem(
                        value: 'kunci',
                        child: MenuRow(Icons.vpn_key_outlined, 'Isi Kunci Jawaban',
                            iconColor: AppTheme.secondary)),
                    const PopupMenuItem(
                        value: 'esai',
                        child: MenuRow(Icons.rate_review_outlined,
                            'Koreksi Esai (nilai manual)',
                            iconColor: AppTheme.secondary)),
                    if (Api.role == 'admin')
                      const PopupMenuItem(
                          value: 'akun',
                          child: MenuRow(Icons.badge_outlined,
                              'Daftar Akun + Password',
                              iconColor: AppTheme.accent)),
                    const PopupMenuItem(
                        value: 'nomor',
                        child: MenuRow(Icons.format_list_numbered,
                            'Terbitkan Nomor (TKJ-1-2627-01)',
                            iconColor: AppTheme.secondary)),
                    const PopupMenuItem(
                        value: 'cetak',
                        child: MenuRow(Icons.print_outlined,
                            'Cetak Kartu + Nominatif')),
                    const PopupMenuItem(
                        value: 'duplikat',
                        child: MenuRow(Icons.copy_all_outlined,
                            'Duplikat ke Banyak Rombel')),
                    const PopupMenuItem(
                        value: 'hapus',
                        child: MenuRow(Icons.delete_forever_outlined,
                            'Hapus Ujian', danger: true)),
                  ],
                  icon: const Icon(Icons.more_vert),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'aktif':
        return 'SEDANG BERLANGSUNG';
      case 'selesai':
        return 'SELESAI';
      case 'dibatalkan':
        return 'DIBATALKAN';
      default:
        return 'DRAFT';
    }
  }

  Future<void> _terbitkanNomor(Map<String, dynamic> u) async {
    try {
      final res = await Api.client.rpc('terbitkan_nomor_peserta',
          params: {'p_ujian': u['id']});
      final m = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
      _snack('Nomor ${m['format'] ?? 'KODE-S-YYZZ-NN'}: ${m['total'] ?? 0} peserta • cth ${m['contoh'] ?? ''}');
      _load();
      if (!mounted) return;
      // langsung tawarkan cetak setelah terbit
      final cetak = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Nomor terbit — cetak?'),
          content: Text(
              'Contoh: ${m['contoh'] ?? '-'}\nFormat TKJ-1-2627-01 = Jurusan-Semester(1 Ganjil/2 Genap)-Tahun-Urut abjad per jurusan.\n\nBuka layar cetak (kartu + nominatif PDF)?',
              style: const TextStyle(fontSize: 13, height: 1.5)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Nanti')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cetak')),
          ],
        ),
      );
      if (cetak == true && mounted) {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CetakPesertaScreen(ujian: u)));
      }
    } catch (e) {
      _snack('Gagal menerbitkan nomor: $e', error: true);
    }
  }

  void _cetakPeserta(Map<String, dynamic> u) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CetakPesertaScreen(ujian: u)));
  }

  Future<void> _duplikatRombel(Map<String, dynamic> base) async {
    final created = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DuplikatSheet(base: base),
    );
    if (created != null && created.isNotEmpty && mounted) {
      _snack('${created.length} ujian tersalin ke rombel (DRAFT — atur jam & aktifkan)');
      _load();
    }
  }

  static const _hariNm = {1: 'Senin', 2: 'Selasa', 3: 'Rabu', 4: 'Kamis', 5: 'Jumat', 6: 'Sabtu'};

  String _hhmm(dynamic v) {
    final s = (v ?? '').toString();
    return s.length >= 5 ? s.substring(0, 5) : (s.isEmpty ? '—' : s);
  }

  String _jam(String? iso) {

    final d = DateTime.tryParse(iso ?? '');
    if (d == null) return '?';
    final l = d.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _hapusUjian(Map<String, dynamic> u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus Ujian'),
        content: Text(
            'Hapus "${u['nama']}" beserta peserta, jawaban, dan nilai peserta ujian ini?\n\nBank soal TIDAK ikut terhapus.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.client.rpc('admin_hapus_ujian', params: {'p_ujian': u['id']});
      _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ujian dihapus + data turunannya')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal hapus: $e'), backgroundColor: AppTheme.danger));
    }
  }

  /// Bottom-sheet kelola soal milik SATU ujian: urut, tambah dari bank (filter mapel ujian),
  /// buang soal — tanpa harus ke halaman Bank Soal.
  Future<void> _kelolaSoal(Map<String, dynamic> u) async {
    List<String> ids = List<String>.from(
        (u['soal_list'] as List?)?.map((e) => e.toString()).toList() ?? []);
    Map<String, Map<String, dynamic>> detail = {};
    try {
      if (ids.isNotEmpty) {
        final rows = await Api.client
            .from('bank_soal')
            .select('id,jenis,soal,bobot,mata_pelajaran(nama)')
            .inFilter('id', ids);
        for (final r in (rows as List)) {
          detail[r['id'].toString()] = Map<String, dynamic>.from(r);
        }
      }
    } catch (_) {}
    if (!context.mounted) return;
    bool changed = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (bc) => StatefulBuilder(
        builder: (bc, setSt) => SizedBox(
          height: MediaQuery.of(bc).size.height * 0.72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Soal: ${u['nama']}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    Text('${ids.length} soal',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          // bank soal dengan filter mapel ujian ini (bisa ganti/semua)
                          final picked = await showDialog<List<String>>(
                            context: bc,
                            builder: (_) => _MapelBankPicker(
                              ujianMapelId: u['mapel_id']?.toString(),
                              ujianMapel: u['mata_pelajaran'] is Map
                                  ? (u['mata_pelajaran'] as Map)['nama']
                                      ?.toString() ?? ''
                                  : '',
                              selected: ids,
                            ),
                          );
                          if (picked != null) {
                            setSt(() {
                              ids = picked;
                              changed = true;
                            });
                          }
                        },
                        icon: const Icon(Icons.library_add_outlined),
                        label: const Text('Ambil / Susun dari Bank Soal'),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 16),
              Expanded(
                child: ids.isEmpty
                    ? const Center(
                        child: Text('Belum ada soal — ambil dari Bank Soal',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: ids.length,
                        itemBuilder: (bc, i) {
                          final d = detail[ids[i]];
                          final jenis = d?['jenis'] ?? '?';
                          return Dismissible(
                            key: ValueKey('${ids[i]}-$i'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                                color: AppTheme.danger.withValues(alpha: 0.15),
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.only(right: 16),
                                child: const Icon(Icons.delete_outline,
                                    color: AppTheme.danger)),
                            onDismissed: (_) => setSt(() {
                                  ids.removeAt(i);
                                  changed = true;
                                }),
                            child: ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                  radius: 13,
                                  backgroundColor: AppTheme.primary,
                                  child: Text('${i + 1}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white))),
                              title: Text(
                                  (d?['soal'] ?? '…').toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12.5)),
                              subtitle: Text(
                                  '${jenis.toString().toUpperCase()} • ${d?['mata_pelajaran'] is Map ? (d!['mata_pelajaran'] as Map)['nama'] : ''}'
                                  ,
                                  style: const TextStyle(
                                      fontSize: 10.5,
                                      color: Colors.grey)),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    size: 18, color: AppTheme.danger),
                                onPressed: () => setSt(() {
                                  ids.removeAt(i);
                                  changed = true;
                                }),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(bc),
                          child: const Text('Tutup'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.secondary),
                          onPressed: () async {
                            try {
                              await Api.client
                                  .from('ujian')
                                  .update({'soal_list': ids})
                                  .eq('id', u['id']);
                              if (bc.mounted) {
                                Navigator.pop(bc);
                                _load();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Soal ujian diperbarui (${ids.length})'),
                                          backgroundColor:
                                              AppTheme.secondary));
                                }
                              }
                            } catch (e) {
                              if (bc.mounted) {
                                ScaffoldMessenger.of(bc).showSnackBar(
                                    SnackBar(
                                        content: Text('Gagal: $e'),
                                        backgroundColor:
                                            AppTheme.danger));
                              }
                            }
                          },
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Simpan Urutan'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
/// Dialog ambil soal dari bank dengan FILTER mata pelajaran (default: mapel ujian ini)
class _MapelBankPicker extends StatefulWidget {
  final String? ujianMapelId;
  final String ujianMapel;
  final List<String> selected;
  const _MapelBankPicker(
      {this.ujianMapelId, this.ujianMapel = '', required this.selected});

  @override
  State<_MapelBankPicker> createState() => _MapelBankPickerState();
}

class _MapelBankPickerState extends State<_MapelBankPicker> {
  List<Map<String, dynamic>> _rows = [];
  String? _mapelId;
  String _q = '';
  late final List<String> _order = List.of(widget.selected);
  late final Set<String> _sel = widget.selected.toSet();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _mapelId = widget.ujianMapelId;
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await Api.client
          .from('bank_soal')
          .select('id,jenis,soal,bobot,mapel_id,mata_pelajaran(nama)')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<dynamic> get _mapelOpts {
    final seen = <String>{};
    final out = <dynamic>[
      {'id': null, 'nama': 'Semua Mapel'}
    ];
    for (final r in _rows) {
      final id = r['mapel_id']?.toString() ?? '';
      final nama = r['mata_pelajaran'] is Map
          ? (r['mata_pelajaran'] as Map)['nama']?.toString() ?? ''
          : '';
      if (id.isNotEmpty && !seen.contains(id)) {
        seen.add(id);
        out.add({'id': id, 'nama': nama.isEmpty ? id.substring(0, 6) : nama});
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _rows.where((r) {
      if (_mapelId != null && r['mapel_id']?.toString() != _mapelId) return false;
      if (_q.isNotEmpty &&
          !r['soal'].toString().toLowerCase().contains(_q.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
    return AlertDialog(
      insetPadding: const EdgeInsets.all(10),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      title: Row(
        children: [
          const Icon(Icons.library_books_outlined, size: 20),
          const SizedBox(width: 8),
          const Text('Bank Soal', style: TextStyle(fontSize: 16)),
          const Spacer(),
          Text('${_sel.length} dipilih',
              style: const TextStyle(fontSize: 12, color: AppTheme.secondary)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.66,
        child: Column(
          children: [
            DropdownButtonFormField<dynamic>(
              value: _mapelOpts.firstWhere(
                (o) => o['id'] == _mapelId,
                orElse: () => _mapelOpts.first,
              ),
              isExpanded: true,
              borderRadius: BorderRadius.circular(12),
              items: _mapelOpts
                  .map((o) => DropdownMenuItem(
                      value: o,
                      child: Text('Mapel: ${o['nama']}',
                          style: const TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => _mapelId = v?['id']),
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                hintText: 'Cari teks soal...',
                prefixIcon: Icon(Icons.search, size: 18),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? const Center(
                          child: Text('Bank soal masih kosong untuk filter ini',
                              style: TextStyle(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (c, i) {
                            final s = filtered[i];
                            final id = s['id'].toString();
                            final on = _sel.contains(id);
                            final jenis = s['jenis'].toString().toUpperCase();
                            return CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: on,
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  _sel.add(id);
                                  _order.add(id);
                                } else {
                                  _sel.remove(id);
                                  _order.remove(id);
                                }
                              }),
                              title: Text(
                                  s['soal'].toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12)),
                              subtitle: Text(
                                '$jenis • bobot ${s['bobot'] ?? 1} • ${s['mata_pelajaran'] is Map ? (s['mata_pelajaran'] as Map)['nama'] ?? '' : ''}',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.secondary),
          onPressed: () => Navigator.pop(context, _order.toList()),
          child: const Text('Gunakan'),
        ),
      ],
    );
  }
}

class _DuplikatSheet extends StatefulWidget {
  final Map<String, dynamic> base;
  const _DuplikatSheet({required this.base});

  @override
  State<_DuplikatSheet> createState() => _DuplikatSheetState();
}

class _DuplikatSheetState extends State<_DuplikatSheet> {
  List<dynamic> _rombel = [];
  final Set<String> _pick = {};
  bool _load = true;
  bool _run = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _ambil();
  }

  Future<void> _ambil() async {
    try {
      final rows = await Api.client.from('kelas').select('id,nama').order('nama');
      if (!mounted) return;
      setState(() {
        _rombel = List<dynamic>.from(rows);
        _load = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _err = '$e';
        _load = false;
      });
    }
  }

  Future<void> _jalan() async {
    if (_pick.isEmpty) return;
    setState(() => _run = true);
    final b = widget.base;
    final made = <String>[];
    for (final kid in _pick) {
      final k = _rombel.firstWhere((r) => '${r['id']}' == kid);
      try {
        final r = await Api.client.from('ujian').insert({
          'nama': '${b['nama']} — ${k['nama']}',
          'jenis_ujian_id': b['jenis_ujian_id'],
          'mapel_id': b['mapel_id'],
          'kelas_id': kid,
          'guru_id': b['guru_id'],
          'tanggal': b['tanggal'],
          'sesi_id': b['sesi_id'],
          'alokasi_menit': b['alokasi_menit'],
          'token': '',
          'soal_list': b['soal_list'],
          'status': 'draft',
          'waktu_mulai': b['waktu_mulai'],
          'waktu_selesai': b['waktu_selesai'],
          'catatan': 'salinan dari ${b['nama']}',
        }).select('id');
        if (r.isNotEmpty) made.add('${r.first['id']}');
      } catch (e) {
        if (!mounted) return;
        setState(() => _err = 'Gagal salin ${k['nama']}: $e');
      }
    }
    if (!mounted) return;
    Navigator.pop(context, made);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.base;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: _load
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Salin Ujian ke Banyak Rombel',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Sumber: ${b['nama']}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                    const Text(
                        'Tiap rombel dapat ujian sendiri — soal sama, status DRAFT. Atur jam tiap kelas lalu Aktifkan.',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        children: [
                          for (final r in _rombel)
                            CheckboxListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              value: _pick.contains('${r['id']}'),
                              title: Text('${r['nama']}',
                                  style: const TextStyle(fontSize: 14)),
                              onChanged: (on) => setState(() {
                                if (on == true) {
                                  _pick.add('${r['id']}');
                                } else {
                                  _pick.remove('${r['id']}');
                                }
                              }),
                            ),
                        ],
                      ),
                    ),
                    if (_err != null)
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(_err!,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.red)),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Batal')),
                        const Spacer(),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.secondary),
                          onPressed:
                              _run || _pick.isEmpty ? null : _jalan,
                          icon: _run
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.copy_all, size: 18),
                          label: Text('Salin ${_pick.length} rombel'),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
