import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/design.dart';
import '../../services/app_update.dart';
import '../../widgets/dashboard_header.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  UpdateInfo? _info;
  String _current = '-';
  bool _checking = false;
  bool _auto = true;
  bool _busy = false;
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final label = await AppUpdate.currentLabel();
    final auto = await AppUpdate.autoEnabled();
    if (!mounted) return;
    setState(() {
      _current = label;
      _auto = auto;
    });
    await _check();
  }

  Future<void> _check() async {
    if (kIsWeb) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    final info = await AppUpdate.check();
    if (!mounted) return;
    setState(() {
      _info = info;
      _checking = false;
    });
  }

  Future<void> _downloadAndInstall() async {
    final info = _info;
    if (info == null) return;
    setState(() {
      _busy = true;
      _progress = 0;
      _error = null;
    });
    try {
      final granted = await AppUpdate.requestInstallPermission();
      if (!granted && mounted) {
        setState(() => _error =
            'Izin "Pasang aplikasi tak dikenal" belum diberikan. '
            'Silakan aktifkan di pengaturan, lalu ulangi.');
        return;
      }
      final path = await AppUpdate.download(info.apkUrl, (p) {
        if (mounted) setState(() => _progress = p);
      });
      await AppUpdate.install(path);
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Installer dibuka — ikuti petunjuk di layar'),
            backgroundColor: AppTheme.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: DashboardHeader(
        title: 'PEMBARUAN APLIKASI',
        subtitle: 'Unduh versi terbaru langsung dari aplikasi',
        showBack: true,
        stats: [('versi', _current)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (kIsWeb)
            Cbt.card(
              child: Row(
                children: [
                  Cbt.iconBox(Icons.web),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Pembaruan APK otomatis hanya tersedia di aplikasi Android.',
                      style: TextStyle(fontSize: 13, color: Cbt.inkSoft),
                    ),
                  ),
                ],
              ),
            ),
          if (!kIsWeb) ...[
            Cbt.card(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: SwitchListTile(
                secondary: const Icon(Icons.autorenew, color: Cbt.blue),
                title: const Text('Cek otomatis saat dibuka',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: Cbt.ink)),
                subtitle: const Text('Beritahu kalau ada versi baru',
                    style: TextStyle(fontSize: 12)),
                value: _auto,
                onChanged: (v) async {
                  setState(() => _auto = v);
                  await AppUpdate.setAutoEnabled(v);
                },
              ),
            ),
            const SizedBox(height: 10),
            Cbt.card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Cbt.iconBox(Icons.info_outline),
                      const SizedBox(width: 12),
                      const Text('Status versi',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Cbt.ink)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _row('Versi terpasang', _current),
                  const SizedBox(height: 8),
                  _row(
                    'Versi terbaru',
                    _checking
                        ? 'Memeriksa…'
                        : (_info?.label ?? 'Sudah yang terbaru'),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _checking ? null : _check,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(_checking ? 'Memeriksa…' : 'Periksa sekarang'),
                    ),
                  ),
                ],
              ),
            ),
            if (_info != null) ...[
              const SizedBox(height: 10),
              Cbt.card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Cbt.iconBox(Icons.system_update, color: Cbt.teal),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Versi ${_info!.label} tersedia',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Cbt.ink)),
                              const SizedBox(height: 2),
                              const Text('Unduh APK lalu pasang otomatis',
                                  style: TextStyle(fontSize: 12, color: Cbt.muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_info!.notes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _info!.notes,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11.5, color: Cbt.inkSoft),
                        ),
                      ),
                    ],
                    if (_busy) ...[
                      const SizedBox(height: 14),
                      LinearProgressIndicator(
                        value: _progress,
                        minHeight: 7,
                        borderRadius: BorderRadius.circular(99),
                        backgroundColor: const Color(0xFFE8F1FF),
                        color: Cbt.blue,
                      ),
                      const SizedBox(height: 6),
                      Text('${(_progress * 100).round()}%',
                          style: const TextStyle(
                              fontSize: 11, color: Cbt.muted)),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _downloadAndInstall,
                        style: FilledButton.styleFrom(
                          backgroundColor: Cbt.blue,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: Text(_busy
                            ? 'Mengunduh…'
                            : 'Unduh & Pasang ${_info!.label}'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Cbt.card(
                color: const Color(0xFFFFF1F2),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Cbt.red),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFFB91C1C))),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Cbt.card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Cbt.iconBox(Icons.admin_panel_settings, color: Cbt.amber),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Izin pemasangan',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Cbt.ink)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Android meminta izin "Pasang aplikasi tak dikenal" '
                    '(Install unknown apps) sekali saat pertama kali memperbarui.',
                    style: TextStyle(fontSize: 12, color: Cbt.muted, height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await AppUpdate.requestInstallPermission();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok
                              ? 'Izin pemasangan sudah aktif'
                              : 'Aktifkan izin di pengaturan yang terbuka'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings, size: 18),
                    label: const Text('Beri izin pemasangan'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, color: Cbt.muted)),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: Cbt.ink)),
        ],
      );
}
