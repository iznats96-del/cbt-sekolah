/// Utilitas tampilan soal MENJODOHKAN.
///
/// Struktur data jodoh:
///   opsi = { "kiri": [item soal...], "kanan": [pilihan jawaban...] }
///   kunci = { "map": { "0": "2", ... } }   (index kiri -> index kanan)
///
/// Field `soal` TIDAK dipakai sebagai identitas/pertanyaan utama untuk jodoh:
/// item di kolom kiri yang menjadi soalnya. Ini dipakai seragam di halaman
/// daftar soal, detail soal, form edit, dan rekap nilai.
class SoalJodoh {
  const SoalJodoh._();

  static bool isJodoh(dynamic jenis) {
    final j = jenis?.toString().toLowerCase() ?? '';
    return j == 'jodoh' || j == 'menjodohkan';
  }

  /// Item kolom kiri (adalah soalnya).
  static List<String> kiri(dynamic opsi) {
    if (opsi is Map) {
      final k = opsi['kiri'];
      if (k is List) {
        return k
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }
    return const [];
  }

  /// Pilihan kolom kanan.
  static List<String> kanan(dynamic opsi) {
    if (opsi is Map) {
      final k = opsi['kanan'];
      if (k is List) {
        return k
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }
    return const [];
  }

  static int jumlahPasangan(dynamic opsi) => kiri(opsi).length;

  /// Nama jenis yang ditampilkan ke user.
  static String labelJenis(dynamic jenis) {
    final j = jenis?.toString().toLowerCase() ?? 'pg';
    if (isJodoh(j)) return 'Menjodohkan';
    if (j == 'essay') return 'Essay';
    return 'Pilihan Ganda';
  }

  /// Judul preview untuk daftar soal.
  /// Jodoh  -> "Menjodohkan: Phishing, Malware, Trojan, +2 lainnya"
  /// Lainnya-> teks soal seperti biasa.
  static String judul(
    dynamic jenis,
    dynamic soal,
    dynamic opsi, {
    int maxItem = 3,
    int maxPanjangItem = 28,
  }) {
    if (!isJodoh(jenis)) return (soal ?? '').toString().trim();
    final k = kiri(opsi);
    if (k.isEmpty) return 'Menjodohkan';
    final tampil = k.take(maxItem).map((e) {
      final t = e.replaceAll(RegExp(r'\s+'), ' ').trim();
      return t.length > maxPanjangItem ? '${t.substring(0, maxPanjangItem)}…' : t;
    }).toList();
    final sisa = k.length - tampil.length;
    return 'Menjodohkan: ${tampil.join(', ')}${sisa > 0 ? ', +$sisa lainnya' : ''}';
  }

  /// Teks yang bisa dicari (daftar soal).
  static String teksPencarian(dynamic jenis, dynamic soal, dynamic opsi) {
    final buff = StringBuffer()..write((soal ?? '').toString());
    if (isJodoh(jenis)) {
      buff
        ..write(' menjodohkan')
        ..write(' ${kiri(opsi).join(' ')}')
        ..write(' ${kanan(opsi).join(' ')}');
    }
    return buff.toString().toLowerCase();
  }

  /// Instruksi otomatis yang tampil di halaman ujian siswa.
  static const String instruksi =
      'Pasangkan setiap item di kolom kiri dengan jawaban yang sesuai di kolom kanan.';
}
