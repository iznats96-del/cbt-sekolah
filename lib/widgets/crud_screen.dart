import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/api.dart';
import '../screens/home.dart';
import 'state_views.dart';

/// Definisi kolom untuk form CRUD generik.
class CrudField {
  final String key;
  final String label;
  final String type; // text, textarea, number, select, date, bool, password
  final List<DropdownItem>? options;
  final bool required;
  final String? hint;
  final bool readOnly;

  const CrudField(
    this.key, {
    required this.label,
    this.type = 'text',
    this.options,
    this.required = false,
    this.hint,
    this.readOnly = false,
  });
}

class DropdownItem {
  final String value;
  final String label;
  const DropdownItem(this.value, this.label);
}

/// Layar CRUD generik berbasis daftar + form dialog.
class CrudScreen extends StatefulWidget {
  final String title;
  final String table;
  final List<CrudField> fields;
  final String displayField;
  final List<String> columns;
  final Map<String, dynamic> Function()? defaults;
  final String? orderBy;
  final bool Function(Map<String, dynamic> row)? canEdit;
  final List<Widget> Function(BuildContext context, Map<String, dynamic> row)? extraActions;
  final String? extraSelect;
  final Map<String, String Function(Map<String, dynamic> row)>? colRender;
  final bool showLogout;
  const CrudScreen({
    super.key,
    required this.title,
    required this.table,
    required this.fields,
    required this.displayField,
    required this.columns,
    this.defaults,
    this.orderBy,
    this.canEdit,
    this.extraActions,
    this.extraSelect,
    this.colRender,
    this.showLogout = false,
  });

  @override
  State<CrudScreen> createState() => _CrudScreenState();
}

class _CrudScreenState extends State<CrudScreen> {
  late Crud _crud;
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _crud = Crud(widget.table, defaults: widget.defaults);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sel = widget.extraSelect == null ? '*' : '*,${widget.extraSelect}';
      dynamic q = Api.client.from(widget.table).select(sel);
      if (widget.orderBy != null) q = q.order(widget.orderBy!);
      final rows = await q.limit(500);
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat data: $e';
        _loading = false;
      });
    }
  }

  Future<void> _openForm([Map<String, dynamic>? row]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CrudFormDialog(
        fields: widget.fields,
        initial: row,
      ),
    );
    if (result == null) return;
    try {
      if (row != null) {
        await _crud.update(row['id'] as String, result);
      } else {
        await _crud.create(result);
      }
      _load();
    } catch (e) {
      _showSnack('Gagal menyimpan: $e', error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus'),
        content: Text('Yakin hapus "${row[widget.displayField]}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _crud.delete(row['id'] as String);
      _load();
    } catch (e) {
      final s = e.toString();
      // Foreign key: data masih dipakai tabel lain (mis. mapel dipakai ujian)
      if (s.contains('23503') || s.contains('foreign key')) {
        final tbl = _referencedBy(s);
        if (mounted) {
          showDialog(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Tidak bisa dihapus'),
              content: Text(
                  '"${row[widget.displayField]}" masih dipakai data lain'
                  '${tbl != null ? ' ($tbl)' : ''}.\n\n'
                  'Hapus/pindahkan dulu data terkait, baru data ini bisa dihapus.'),
              actions: [
                FilledButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Mengerti')),
              ],
            ),
          );
        }
        return;
      }
      _showSnack('Gagal hapus: $s', error: true);
    }
  }

  /// Ambil nama tabel dari pesan error FK PostgREST ("on table \"ujian\"").
  String? _referencedBy(String err) {
    final m = RegExp(r'on table "([^"]+)"').firstMatch(err);
    return m?.group(1);
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: error ? AppTheme.danger : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: Text(widget.title),
        actions: widget.showLogout ? const [LogoutButton()] : null,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primary,
        onPressed: () => _openForm(),
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
    if (_rows.isEmpty) {
      return EmptyState(
        icon: Icons.inbox_outlined,
        title: 'Belum ada ${widget.title}',
        actionLabel: 'Tambah',
        onAction: () => _openForm(),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (context, i) {
          final row = _rows[i];
          return Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              title: Text(
                '${row[widget.displayField] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                widget.columns
                    .map((c) {
                      final r = widget.colRender?[c];
                      if (r != null) {
                        final v = r(row);
                        return v.isEmpty ? null : v;
                      }
                      return row[c]?.toString().isNotEmpty == true ? row[c].toString() : null;
                    })
                    .whereType<String>()
                    .join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...?widget.extraActions?.call(context, row),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _openForm(row),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                    onPressed: () => _delete(row),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CrudFormDialog extends StatefulWidget {
  final List<CrudField> fields;
  final Map<String, dynamic>? initial;
  const _CrudFormDialog({required this.fields, this.initial});

  @override
  State<_CrudFormDialog> createState() => _CrudFormDialogState();
}

class _CrudFormDialogState extends State<_CrudFormDialog> {
  final Map<String, TextEditingController> _ctrl = {};
  final Map<String, String?> _select = {};
  final Map<String, bool> _bool = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      final v = widget.initial?[f.key]?.toString() ?? '';
      _ctrl[f.key] = TextEditingController(text: v);
      if (f.type == 'select') _select[f.key] = v;
      if (f.type == 'bool') _bool[f.key] = (widget.initial?[f.key] == true);
    }
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final data = <String, dynamic>{};
    for (final f in widget.fields) {
      if (f.readOnly) {
        if (widget.initial != null && widget.initial![f.key] != null) {
          data[f.key] = widget.initial![f.key];
        }
        continue;
      }
      switch (f.type) {
        case 'bool':
          data[f.key] = _bool[f.key] ?? false;
          break;
        case 'number':
          final t = _ctrl[f.key]!.text.trim();
          data[f.key] = t.isEmpty ? null : int.tryParse(t) ?? double.tryParse(t);
          break;
        case 'select':
          // Nilai select disimpan di _select (dropdown), bukan di _ctrl.
          final sv = _select[f.key];
          if (f.required && (sv == null || sv.isEmpty)) {
            _show('${f.label} wajib diisi');
            return;
          }
          data[f.key] = (sv == null || sv.isEmpty) ? null : sv;
          break;
        case 'date':
        case 'text':
        case 'textarea':
        default:
          final t = _ctrl[f.key]!.text.trim();
          if (f.required && t.isEmpty) {
            _show('${f.label} wajib diisi');
            return;
          }
          data[f.key] = t.isEmpty ? null : t;
      }
    }
    setState(() => _loading = true);
    try {
      Navigator.pop(context, data);
    } catch (e) {
      _show('Gagal: $e');
      setState(() => _loading = false);
    }
  }

  void _show(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m), backgroundColor: AppTheme.danger));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Tambah Data' : 'Edit Data'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.fields.map(_buildField).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')),
        FilledButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const ButtonSpinner()
                : const Text('Simpan')),
      ],
    );
  }

  Widget _buildField(CrudField f) {
    switch (f.type) {
      case 'textarea':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _ctrl[f.key],
            maxLines: 4,
            decoration: InputDecoration(labelText: f.label),
          ),
        );
      case 'bool':
        return CheckboxListTile(
          value: _bool[f.key] ?? false,
          onChanged: (v) => setState(() => _bool[f.key] = v ?? false),
          title: Text(f.label),
        );
      case 'select':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            initialValue: _select[f.key]?.isEmpty == true ? null : _select[f.key],
            decoration: InputDecoration(
                labelText: f.label,
                helperText: f.required ? 'wajib' : 'opsional'),
            items: (f.options ?? [])
                .map((o) => DropdownMenuItem(value: o.value, child: Text(o.label)))
                .toList(),
            onChanged: (v) => setState(() => _select[f.key] = v),
          ),
        );
      case 'password':
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _ctrl[f.key],
            obscureText: true,
            decoration: InputDecoration(labelText: f.label),
          ),
        );
      default:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _ctrl[f.key],
            readOnly: f.readOnly,
            keyboardType: f.type == 'number'
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            decoration: InputDecoration(
                labelText: f.label,
                hintText: f.hint,
                helperText: f.required ? 'wajib' : null),
          ),
        );
    }
  }
}

/// Helper untuk mendapatkan daftar opsi dropdown dari tabel Supabase.
Future<List<DropdownItem>> fetchDropdown(
    String table, String labelField, String valueField) async {
  final rows = await Api.client
      .from(table)
      .select('$valueField,$labelField')
      .order(labelField);
  return (rows as List)
      .map((r) {
        final m = Map<String, dynamic>.from(r as Map);
        return DropdownItem('${m[valueField]}', '${m[labelField]}');
      })
      .toList();
}