import 'package:flutter/material.dart';

import '../../widgets/crud_screen.dart';

/// Tampilan tabel kelas lama (CRUD cepat) — sisa dari menu lama.
class CrudKelasScreen extends StatelessWidget {
  const CrudKelasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CrudScreen(
      title: 'Kelola Kelas (tabel)',
      table: 'kelas',
      displayField: 'nama',
      columns: ['tingkat'],
      fields: const [
        CrudField('nama', label: 'Nama Kelas', required: true, hint: 'contoh: X TKI 1'),
        CrudField('tingkat', label: 'Tingkat', type: 'number'),
      ],
    );
  }
}
