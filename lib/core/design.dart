import 'package:flutter/material.dart';

/// Design tokens & komponen kecil yang dipakai layar utama CBT.
/// Tujuannya: satu bahasa visual yang khas "lembar jawaban ujian",
/// bukan tampilan Material default yang generic.
class Cbt {
  // ── Warna: kertas ujian + tinta biru ───────────────────────
  static const ink = Color(0xFF12263A);        // tinta navy (bukan hitam)
  static const inkSoft = Color(0xFF3D5873);
  static const paper = Color(0xFFFAFBFD);      // kertas (cool, bukan cream)
  static const line = Color(0xFFDDE5EE);
  static const blue = Color(0xFF1A6DB4);       // biru penggaris / pilihan
  static const teal = Color(0xFF2E9B8F);       // sudah dijawab
  static const amber = Color(0xFFF4A940);      // ragu-ragu
  static const red = Color(0xFFD9534F);
  static const muted = Color(0xFF64748B);

  // ── Tipografi ───────────────────────────────────────────────
  static const display = TextStyle(
    fontSize: 34, fontWeight: FontWeight.w700,
    letterSpacing: -1.2, fontFeatures: [FontFeature.tabularFigures()],
  );
  static const overline = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w700,
    letterSpacing: 1.6, color: muted,
  );
  static const question = TextStyle(
    fontSize: 19, fontWeight: FontWeight.w500,
    height: 1.5, color: ink, letterSpacing: -0.2,
  );
  static const option = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w500,
    height: 1.35, color: ink,
  );
  static const caption = TextStyle(fontSize: 12, color: muted);

  // ── Komponen ────────────────────────────────────────────────

  /// Label kecil di atas konten (bukan ALL-CAPS dekoratif).
  static Widget label(String text, {Color? color}) => Text(
        text,
        style: overline.copyWith(color: color ?? muted),
      );

  /// Kartu kertas dengan garis tipis dan sudut 14.
  static Widget card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(18),
    Color? color,
    Border? border,
  }) =>
      Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: color ?? paper,
          borderRadius: BorderRadius.circular(14),
          border: border ?? Border.all(color: line),
        ),
        child: child,
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: child,
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: bg,
                side: BorderSide(color: line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          hintStyle: const TextStyle(color: muted, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: muted),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: line),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: blue, width: 1.5),
          ),
        ),
      );

  /// Keadaan kosong yang memberi arahan (bukan cuma teks).
  static Widget empty({
    required IconData icon,
    required String title,
    String? subtitle,
  }) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: blue.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 34, color: blue),
              ),
              const SizedBox(height: 14),
              Text(title, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ink)),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle, textAlign: TextAlign.center, style: caption),
              ],
            ],
          ),
        ),
      );
}
