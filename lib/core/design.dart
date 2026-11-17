import 'package:flutter/material.dart';

/// Design tokens & komponen kecil yang dipakai lintas layar CBT.
/// Satu bahasa visual: kartu putih melayang, aksen biru, sudut 18,
/// dan bayangan lembut — bukan tampilan Material default.
class Cbt {
  // ── Warna ────────────────────────────────────────────────────
  static const ink = Color(0xFF12263A);
  static const inkSoft = Color(0xFF3D5873);
  static const paper = Color(0xFFF4F7FF);
  static const line = Color(0xFFE7EDFA);
  static const blue = Color(0xFF2563EB);
  static const teal = Color(0xFF0EA5A4);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);
  static const muted = Color(0xFF64748B);
  static const white = Colors.white;

  static const shadow = [
    BoxShadow(
      color: Color(0x0D1E3A66),
      blurRadius: 10,
      offset: Offset(0, 3),
    ),
  ];

  // ── Tipografi ───────────────────────────────────────────────
  static const display = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const overline = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.1,
    color: muted,
  );
  static const question = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: ink,
    letterSpacing: -0.2,
  );
  static const option = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.35,
    color: ink,
  );
  static const caption = TextStyle(fontSize: 12, color: muted);

  // ── Komponen ────────────────────────────────────────────────

  static Widget label(String text, {Color? color}) => Text(
        text,
        style: overline.copyWith(color: color ?? muted),
      );

  /// Kartu putih melayang dengan bayangan lembut.
  static Widget card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
    Color? color,
    Border? border,
    double radius = 18,
  }) =>
      Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? white,
          borderRadius: BorderRadius.circular(radius),
          border: border ?? Border.all(color: line),
          boxShadow: shadow,
        ),
        child: child,
      );

  /// Ikon bulat dengan latar lembut — dipakai di semua list card.
  static Widget iconBox(IconData icon, {Color color = blue, double size = 44}) =>
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(size * 0.32),
        ),
        child: Icon(icon, color: color, size: size * 0.5),
      );

  /// Pill status kecil.
  static Widget chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
        ),
      );

  /// Tombol aksi utama.
  static Widget button({
    required String text,
    required VoidCallback? onPressed,
    IconData? icon,
    bool filled = true,
    Color? color,
    bool expanded = false,
  }) {
    final bg = color ?? blue;
    final child = Row(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
        Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
    return SizedBox(
      width: expanded ? double.infinity : null,
      height: 46,
      child: filled
          ? FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: bg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: bg,
                side: const BorderSide(color: line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: child,
            ),
    );
  }

  /// Kolom pencarian dengan ikon search di kiri.
  static Widget searchField({
    required TextEditingController controller,
    required String hint,
    ValueChanged<String>? onChanged,
  }) =>
      TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: muted, fontSize: 13.5),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: blue),
          filled: true,
          fillColor: white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: blue, width: 1.5),
          ),
        ),
      );

  /// Keadaan kosong yang memberi arahan.
  static Widget empty({
    required IconData icon,
    required String title,
    String? subtitle,
  }) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: line),
              boxShadow: shadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: blue.withValues(alpha: 0.09),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 32, color: blue),
                ),
                const SizedBox(height: 13),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: ink),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle, textAlign: TextAlign.center, style: caption),
                ],
              ],
            ),
          ),
        ),
      );
}
