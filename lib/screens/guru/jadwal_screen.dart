import 'package:flutter/material.dart';

import '../admin/ujian_list_screen.dart';

class JadwalScreen extends StatelessWidget {
  const JadwalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const UjianListScreen(showLogout: true);
  }
}
