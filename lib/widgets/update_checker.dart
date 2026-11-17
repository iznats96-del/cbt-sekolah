import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/nav.dart';
import '../services/app_update.dart';
import 'update_sheet.dart';

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

    BuildContext? ctx = AppNav.key.currentContext;
    if (ctx == null) {
      await Future.delayed(const Duration(seconds: 2));
      ctx = AppNav.key.currentContext;
    }
    if (ctx == null || !ctx.mounted) return;

    UpdateSheet.show(ctx, info);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
