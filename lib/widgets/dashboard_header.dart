import 'package:flutter/material.dart';

/// Header gradient dipakai lintas dashboard (admin, panitia, guru, cetak kartu).
/// Bisa dipasang langsung sebagai `appBar:` karena implements PreferredSizeWidget.
class DashboardHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String subtitle;
  final List<Widget> actions;
  final List<(String label, String value)> stats;
  final bool showBack;

  const DashboardHeader({
    super.key,
    required this.title,
    this.subtitle = '',
    this.actions = const [],
    this.stats = const [],
    this.showBack = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(150);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (showBack)
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Kembali',
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 20),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 11.5, color: Colors.white70)),
                        ],
                      ],
                    ),
                  ),
                  ...actions,
                ],
              ),
              if (stats.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final s in stats) _pill(s.$1, s.$2),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(fontSize: 10.5, color: Colors.white70)),
          ],
        ),
      );
}
