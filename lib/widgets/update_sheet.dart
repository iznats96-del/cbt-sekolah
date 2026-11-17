import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../services/app_update.dart';

class UpdateSheet extends StatefulWidget {
  final UpdateInfo info;

  const UpdateSheet({super.key, required this.info});

  static Future<void> show(BuildContext context, UpdateInfo info) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        builder: (_) => UpdateSheet(info: info),
      );

  @override
  State<UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<UpdateSheet> {
  double _progress = 0;
  String _status = 'Menyiapkan pembaruan…';
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final granted = await AppUpdate.requestInstallPermission();
    if (!mounted) return;
    if (!granted) {
      setState(() {
        _error = 'Izin pemasangan belum aktif';
        _status = 'Aktifkan izin lalu ulangi';
      });
      return;
    }

    try {
      setState(() => _status = 'Mengunduh pembaruan…');
      final path = await AppUpdate.download(widget.info.apkUrl, (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (!mounted) return;
      setState(() => _status = 'Membuka pemasang…');
      await AppUpdate.install(path);
      if (mounted && context.mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal mengunduh';
          _status = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Color(0x331E3A66),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.system_update_rounded,
                    color: AppTheme.primary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pembaruan aplikasi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF101F3C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _status,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: _error == null ? _progress : null,
              minHeight: 8,
              backgroundColor: const Color(0xFFE8F1FF),
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _error ?? '${(_progress * 100).round()}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _error == null
                      ? AppTheme.primary
                      : AppTheme.danger,
                ),
              ),
              Text(
                widget.info.label,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: FilledButton(
                onPressed: _start,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Coba lagi'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
