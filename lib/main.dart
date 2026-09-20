import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config.dart';
import 'screens/splash_screen.dart';
import 'core/app_theme.dart';

// Aktifkan DevicePreview hanya di Chrome/Web untuk lihat frame HP di VS Code
// import 'package:device_preview/device_preview.dart'; // uncomment jika sudah `flutter pub add device_preview`

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  runApp(const CbtApp());
  // Untuk frame HP di VS Code (Chrome), ganti baris di atas jadi:
  // runApp(DevicePreview(enabled: kIsWeb, builder: (_) => const CbtApp()));
}

class CbtApp extends StatelessWidget {
  const CbtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CBT Sekolah',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}