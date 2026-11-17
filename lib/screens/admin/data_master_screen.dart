import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';

import '../home.dart';
import '../../widgets/crud_screen.dart';
import '../../widgets/dashboard_header.dart';
import '../../widgets/state_views.dart';
import 'import_screen.dart';
import 'jadwal_pelajaran_screen.dart';
import 'kelas_rombel_screen.dart';
import 'siswa_master_grouped_screen.dart';

const _dmBg = Color(0xFFF4F7FF);
const _dmNavy = Color(0xFF101F3C);
const _dmMuted = Color(0xFF8A97B1);
const _dmBlue = Color(0xFF2563EB);

class DataMasterScreen extends StatelessWidget {
  const DataMasterScreen({super.key});

  static const List<({String title, String table, String display})> sections = [
    (title: 'Tahun Pelajaran', table: 'tahun_pelajaran', display: 'nama'),
    (title: 'Jurusan', table: 'jurusan', display: 'nama'),
    (title: 'Mata Pelajaran', table: 'mata_pelajaran', display: 'nama'),
    (title: 'Kelas / Rombel', table: 'kelas', display: 'nama'),
    (title: 'Guru', table: 'guru', display: 'nama'),
    (title: 'Siswa', table: 'siswa', display: 'nama'),
    (title: 'Data Umum', table: 'sekolah', display: 'nama'),
  ];

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String title, Widget Function() page})>[
      (icon: Icons.calendar_month_outlined, title: 'Tahun Pelajaran', page: () => _tahunPelajaran()),
      (icon: Icons.school_outlined, title: 'Jurusan', page: () => _jurusan()),
      (icon: Icons.menu_book_outlined, title: 'Mata Pelajaran', page: () => _mataPelajaran()),
      (icon: Icons.groups_outlined, title: 'Kelas / Rombel', page: () => const KelasRombelScreen()),
      (icon: Icons.person_outline, title: 'Guru', page: () => _guru()),
      (icon: Icons.people_alt_outlined, title: 'Siswa (Grouped)', page: () => const SiswaMasterGroupedScreen()),
      (icon: Icons.people_alt_outlined, title: 'Siswa (Tabel)', page: () => _siswa()),
      (icon: Icons.business_outlined, title: 'Data Umum', page: () => _sekolah()),
      (icon: Icons.upload_file_outlined, title: 'Import Siswa (XLS/XLSX/CSV)', page: () => const ImportScreen(isSiswa: true)),
      (icon: Icons.upload_file_outlined, title: 'Import Mata Pelajaran', page: () => const ImportScreen(isSiswa: false)),
      (icon: Icons.date_range_outlined, title: 'Jadwal Pelajaran (Hari & Jam)', page: () => const JadwalPelajaranScreen()),
    ];

    return Scaffold(
      backgroundColor: _dmBg,
      appBar: DashboardHeader(
        title: 'DATA MASTER',
        subtitle: 'Kelola data pokok sekolah',
        stats: [('menu', '${items.length}')],
        actions: const [LogoutButton()],
      ),
      body: ContentMaxWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Row(
              children: [
                const Icon(Icons.folder_shared_outlined,
                    size: 18, color: _dmBlue),
                const SizedBox(width: 8),
                const Text('DAFTAR DATA',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _dmNavy)),
                const Spacer(),
                Text('${items.length} menu',
                    style: const TextStyle(fontSize: 11, color: _dmMuted)),
              ],
            ),
            const SizedBox(height: 12),
            for (final item in items)
              Container(
                margin: const EdgeInsets.only(bottom: 9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => item.page()),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _dmBlue.withValues(alpha: 0.11),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(item.icon, color: _dmBlue, size: 21),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(item.title,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: _dmNavy)),
                          ),
                          const Icon(Icons.chevron_right,
                              color: _dmMuted, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tahunPelajaran() {
    return CrudScreen(
      title: 'Tahun Pelajaran',
      table: 'tahun_pelajaran',
      displayField: 'nama',
      orderBy: 'created_at',
      columns: ['semester', 'is_active'],
      fields: const [
        CrudField('nama', label: 'Tahun Pelajaran', required: true, hint: 'contoh: 2025/2026'),
        CrudField('semester', label: 'Semester', required: true, options: [
          DropdownItem('Ganjil', 'Ganjil'),
          DropdownItem('Genap', 'Genap'),
        ], type: 'select'),
        CrudField('is_active', label: 'Aktif', type: 'bool'),
      ],
    );
  }

  Widget _jurusan() {
    return CrudScreen(
      title: 'Jurusan',
      table: 'jurusan',
      displayField: 'nama',
      columns: ['singkatan'],
      fields: const [
        CrudField('nama', label: 'Nama Jurusan', required: true, hint: 'contoh: Teknik Komputer dan Jaringan'),
        CrudField('singkatan', label: 'Singkatan', required: true, hint: 'contoh: TKJ'),
        CrudField('deskripsi', label: 'Deskripsi', type: 'textarea'),
      ],
    );
  }

  Widget _mataPelajaran() {
    return CrudScreen(
      title: 'Mata Pelajaran',
      table: 'mata_pelajaran',
      displayField: 'nama',
      columns: ['kode'],
      extraActions: (ctx, row) => [
        IconButton(
          icon: const Icon(Icons.delete_forever_outlined, color: AppTheme.danger),
          tooltip: 'Hapus mapel + semua ujian/soalnya',
          onPressed: () => _hapusMapelCascade(ctx, row),
        ),
      ],
      fields: const [
        CrudField('nama', label: 'Nama Mapel', required: true),
        CrudField('kode', label: 'Kode Mapel'),
        CrudField('kkm', label: 'KKM', required: true, type: 'number', hint: 'contoh: 75'),
      ],
    );
  }

  /// Hapus mapel SEKALIGUS ujian, soal, peserta, jawaban yang terkait (admin/cascade).
  Future<void> _hapusMapelCascade(BuildContext ctx, Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Hapus Mapel + Semua Ujian?'),
        content: Text(
            'Hapus "${row['nama']}" akan MENGHAPUS PERMANEN:\n\n'
            '• semua UJIAN yang pakai mapel ini\n'
            '• semua SOAL (bank soal) mapel ini\n'
            '• semua PESERTA + JAWABAN + NILAI ujian tsb\n'
            '• jadwal pelajaran mapel ini\n\n'
            'Tindakan ini tidak bisa dibatalkan. Lanjutkan?',
            style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Hapus Semua')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final res = await Api.client.rpc('admin_hapus_mapel', params: {'p_mapel': row['id']});
      final m = res is Map ? Map<String, dynamic>.from(res) : <String, dynamic>{};
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text('Terhapus: ${m['ujian_dihapus'] ?? 0} ujian, ${m['soal_dihapus'] ?? 0} soal'),
        backgroundColor: AppTheme.secondary,
      ));
    } catch (e) {
      if (!ctx.mounted) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('Gagal hapus mapel: $e'), backgroundColor: AppTheme.danger));
    }
  }

  Widget _kelas() {
    return CrudScreen(
      title: 'Kelas / Rombel',
      table: 'kelas',
      displayField: 'nama',
      columns: ['tingkat'],
      fields: const [
        CrudField('nama', label: 'Nama Kelas', required: true, hint: 'contoh: X TKI 1'),
        CrudField('tingkat', label: 'Tingkat', required: true, type: 'number', hint: '10, 11, 12'),
      ],
    );
  }

  Widget _guru() {
    return CrudScreen(
      title: 'Guru',
      table: 'guru',
      displayField: 'nama',
      columns: ['nip'],
      fields: const [
        CrudField('nama', label: 'Nama Guru', required: true),
        CrudField('nip', label: 'NIP'),
        CrudField('jabatan', label: 'Jabatan'),
      ],
    );
  }

  Widget _siswa() {
    return CrudScreen(
      title: 'Siswa',
      table: 'siswa',
      displayField: 'nama',
      extraSelect: 'kelas(nama)',
      colRender: {
        'nomor_peserta': (row) {
          final n = row['nomor_peserta']?.toString() ?? '';
          return n.isEmpty ? 'Nomor: -' : 'Nomor: $n';
        },
        'kelas_id': (row) {
          final k = row['kelas'];
          return k is Map && k['nama'] != null ? 'Kelas: ${k['nama']}' : '';
        },
      },
      columns: ['nomor_peserta', 'nis', 'kelas_id'],
      extraActions: (ctx, row) => [
        IconButton(
          icon: const Icon(Icons.copy_outlined, color: AppTheme.primary),
          tooltip: 'Salin nomor peserta',
          onPressed: () {
            final n = row['nomor_peserta']?.toString() ?? '';
            if (n.isNotEmpty) {
              Clipboard.setData(ClipboardData(text: n));
              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                  content: Text('Nomor tersalin'),
                  backgroundColor: AppTheme.secondary));
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.vpn_key_outlined, color: AppTheme.secondary),
          tooltip: 'Password akun',
          onPressed: () => showDialog(
            context: ctx,
            builder: (_) => PasswordAkunDialog(siswa: row),
          ),
        ),
      ],
      fields: const [
        CrudField('nomor_peserta', label: 'Nomor Peserta', readOnly: true, hint: 'auto TKJ-1-2627-01'),
        CrudField('nis', label: 'NIS', required: true),
        CrudField('nisn', label: 'NISN'),
        CrudField('nama', label: 'Nama Siswa', required: true),
        CrudField('jenis_kelamin', label: 'Jenis Kelamin', options: [
          DropdownItem('L', 'Laki-laki'),
          DropdownItem('P', 'Perempuan'),
        ], type: 'select'),
        CrudField('tempat_lahir', label: 'Tempat Lahir'),
        CrudField('tanggal_lahir', label: 'Tanggal Lahir'),
        CrudField('alamat', label: 'Alamat', type: 'textarea'),
        CrudField('no_hp', label: 'No. HP'),
        CrudField('aktive_ok', label: 'Aktif', type: 'bool'),
      ],
    );
  }

  Widget _sekolah() {
    return CrudScreen(
      title: 'Data Umum Sekolah',
      table: 'sekolah',
      displayField: 'nama',
      orderBy: 'updated_at',
      columns: ['npsn', 'kota'],
      fields: const [
        CrudField('nama', label: 'Nama Sekolah', required: true),
        CrudField('npsn', label: 'NPSN'),
        CrudField('alamat', label: 'Alamat', type: 'textarea'),
        CrudField('telp', label: 'Telepon'),
        CrudField('email', label: 'Email'),
        CrudField('website', label: 'Website'),
        CrudField('kepala_sekolah', label: 'Kepala Sekolah'),
        CrudField('nip_kepala', label: 'NIP Kepala Sekolah'),
        CrudField('kota', label: 'Kota'),
        CrudField('provinsi', label: 'Provinsi'),
      ],
    );
  }
}

/// Dialog info/reset password akun siswa (khusus admin).
class PasswordAkunDialog extends StatefulWidget {
  final Map<String, dynamic> siswa;
  const PasswordAkunDialog({super.key, required this.siswa});

  @override
  State<PasswordAkunDialog> createState() => _PasswordAkunDialogState();
}

class _PasswordAkunDialogState extends State<PasswordAkunDialog> {
  String? _pw;
  bool _loading = true;
  bool _resetting = false;
  String? _pesan;

  @override
  void initState() {
    super.initState();
    _cari();
  }

  Future<void> _cari() async {
    try {
      final p = await Api.client
          .from('profiles')
          .select('pw_default')
          .eq('nis', widget.siswa['nis']?.toString() ?? '')
          .limit(1);
      if (!mounted) return;
      setState(() {
        _pw = (p.isNotEmpty && p.first['pw_default'] != null)
            ? p.first['pw_default'].toString() : '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _pw = '';
        _pesan = 'gagal baca: $e';
      });
    }
  }

  Future<void> _reset() async {
    setState(() => _resetting = true);
    try {
      final np = await Api.client.rpc('reset_password_siswa',
          params: {'p_siswa': widget.siswa['id']});
      if (!mounted) return;
      setState(() {
        _pw = np.toString();
        _resetting = false;
        _pesan = 'Password baru dibuat — catat & serahkan ke wali kelas';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resetting = false;
        _pesan = 'Gagal reset: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final nis = widget.siswa['nis']?.toString() ?? '-';
    return AlertDialog(
      title: Text('Akun: ${widget.siswa['nama']}',
          style: const TextStyle(fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Username login  :', style: TextStyle(fontSize: 12)),
          SelectableText(nis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('Password awal  :', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          if (_loading)
            const Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator())
          else if (_pw == null || _pw!.isEmpty)
            const Text(
                '(belum tercatat — akun dibuat sebelum fitur; tekan Reset)',
                style: TextStyle(fontSize: 12, color: Colors.grey))
          else
            SelectableText(_pw!,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5)),
          if (_pesan != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_pesan!,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup')),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: AppTheme.secondary),
          onPressed: _resetting ? null : _reset,
          icon: _resetting
              ? const SizedBox(
                  height: 14, width: 14,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.refresh, size: 16),
          label: const Text('Reset (YP baru)'),
        ),
      ],
    );
  }
}
