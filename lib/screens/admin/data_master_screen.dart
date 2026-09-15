import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';

import '../home.dart';
import '../../widgets/crud_screen.dart';
import 'import_screen.dart';

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
      (icon: Icons.groups_outlined, title: 'Kelas / Rombel', page: () => _kelas()),
      (icon: Icons.person_outline, title: 'Guru', page: () => _guru()),
      (icon: Icons.people_alt_outlined, title: 'Siswa', page: () => _siswa()),
      (icon: Icons.business_outlined, title: 'Data Umum', page: () => _sekolah()),
      (icon: Icons.upload_file_outlined, title: 'Import Siswa (XLS/XLSX/CSV)', page: () => const ImportScreen(isSiswa: true)),
      (icon: Icons.upload_file_outlined, title: 'Import Mata Pelajaran', page: () => const ImportScreen(isSiswa: false)),
    ];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text('DATA MASTER', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
        ),
        ...items.map((item) => Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: Icon(item.icon, color: Theme.of(context).colorScheme.primary),
                title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => item.page()),
                ),
              ),
            )),
        const Divider(height: 24),
        const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Text('TOP MENU', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
        ),
      ],
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
        CrudField('semester', label: 'Semester', options: [
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
        CrudField('singkatan', label: 'Singkatan', hint: 'contoh: TKJ'),
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
      fields: const [
        CrudField('nama', label: 'Nama Mapel', required: true),
        CrudField('kode', label: 'Kode Mapel'),
        CrudField('kkm', label: 'KKM', type: 'number'),
      ],
    );
  }

  Widget _kelas() {
    return CrudScreen(
      title: 'Kelas / Rombel',
      table: 'kelas',
      displayField: 'nama',
      columns: ['tingkat'],
      fields: const [
        CrudField('nama', label: 'Nama Kelas', required: true, hint: 'contoh: X TKI 1'),
        CrudField('tingkat', label: 'Tingkat', type: 'number'),
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
      columns: ['nis', 'kelas_id'],
      extraActions: (ctx, row) => [
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
        CrudField('kota', label: 'Kota'),
        CrudField('provinsi', label: 'Provinsi'),
      ],
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String title;
  const _PlaceholderPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(child: Text('Fitur segera hadir')),
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
