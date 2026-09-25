import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../services/api.dart';
import '../../widgets/state_views.dart';

class PengumumanSiswaScreen extends StatefulWidget {
  const PengumumanSiswaScreen({super.key});

  @override
  State<PengumumanSiswaScreen> createState() => _PengumumanSiswaScreenState();
}

class _PengumumanSiswaScreenState extends State<PengumumanSiswaScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
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
      final rows = await Api.client
          .from('pengumuman')
          .select()
          .eq('aktif', true)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _rows = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat pengumuman: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? ErrorState(message: _error!, onRetry: _load)
            : _rows.isEmpty
                ? const EmptyState(
                    icon: Icons.campaign_outlined,
                    title: 'Belum ada pengumuman',
                    subtitle: 'Coba tarik ke bawah untuk memuat ulang.')
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _rows.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, i) {
                        final r = _rows[i];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: const Icon(Icons.campaign_outlined,
                                color: AppTheme.accent),
                            title: Text('${r['judul']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text('${r['isi'] ?? ''}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis),
                          ),
                        );
                      },
                    ),
                  );
  }
}