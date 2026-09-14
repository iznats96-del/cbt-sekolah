import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../../widgets/crud_screen.dart';

class PengumumanScreen extends StatelessWidget {
  const PengumumanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CrudScreen(
      title: 'Pengumuman',
      table: 'pengumuman',
      displayField: 'judul',
      columns: ['aktif'],
      orderBy: 'created_at',
      fields: const [
        CrudField('judul', label: 'Judul', required: true),
        CrudField('isi', label: 'Isi', type: 'textarea'),
        CrudField('target_role', label: 'Target', options: [
          DropdownItem('semua', 'Semua'),
          DropdownItem('admin', 'Admin'),
          DropdownItem('guru', 'Guru'),
          DropdownItem('siswa', 'Siswa'),
        ], type: 'select'),
        CrudField('aktif', label: 'Aktif', type: 'bool'),
      ],
    );
  }
}