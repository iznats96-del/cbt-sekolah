import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF1A6DB4);
  static const Color secondary = Color(0xFF2E9B8F);
  static const Color accent = Color(0xFFF4A940);
  static const Color danger = Color(0xFFD9534F);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF4F6FA),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: const CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD0D7DE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD0D7DE)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
      ),
    );
  }
}