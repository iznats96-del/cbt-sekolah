import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/shared/update_screen.dart';
import '../services/app_update.dart';

class UpdateChecker extends StatefulWidget {
  final Widget child;
  const UpdateChecker({super.key, required this.child});

  @override
  State<UpdateChecker> createState() => _UpdateCheckerState();
}

class _UpdateCheckerState extends State<UpdateChecker> {
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _maybeCheck();
  }

  Future<void> _maybeCheck() async {
    if (kIsWeb || _shown) return;
    if (Supabase.instance.client.auth.currentSession == null) return;
    if (!await AppUpdate.autoEnabled()) return;
    await Future.delayed(const Duration(seconds: 3));
    final info = await AppUpdate.check();
    if (info == null || !mounted || _shown) return;
    _shown = true;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Pembaruan tersedia'),
        content: Text(
          'Versi ${info.label} sudah dirilis.\n\n'
          '${info.notes.isEmpty ? 'Perbaikan & peningkatan performa.' : info.notes}',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Nanti'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UpdateScreen()),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
