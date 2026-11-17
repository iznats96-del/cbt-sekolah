import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// ─────────────────────────────────────────────────────────────
/// Parser naskah ujian DOCX — FORMAT BARU (ASTS ganjil)
/// ─────────────────────────────────────────────────────────────
/// Format yang didukung:
///  • Kop sekolah + "Mata Pelajaran:", "Kelas/Konsentrasi Keahlian:",
///    "Program Keahlian:", "Waktu: 90 Menit", "Guru Mata Pelajaran:"
///  • "PILIHAN GANDA" -> soal berakhir "(X Poin)" / "?" / "...",
///    opsi dalam satu paragraf dipisah TAB (Word auto-numbering).
///    Huruf bisa eksplisit ("c. News") atau otomatis (tanpa huruf).
///  • "MENJODOHKAN" -> tabel "Soal | Pilihan Jawaban | Jawaban"
///  • "ESSAY URAIAN" -> soal berakhir "(X Poin)"
///  • "KUNCI JAWABAN" -> "1. B, 2. C, ..." (opsional)
/// Lembar jawaban ("JAWABAN PILIHAN GANDA", "? ? ?", titik-titik) diabaikan.
/// ─────────────────────────────────────────────────────────────

class PgSoal {
  final String soal;
  final List<String> opsi;
  final Map<String, String> hurufOpsi;
  String? kunci;
  final String? imgPath;
  PgSoal(this.soal, this.opsi, this.hurufOpsi, this.kunci, this.imgPath);
}

class EssaySoal {
  final String soal;
  EssaySoal(this.soal);
}

/// Satu grup jodoh: item kiri (kolom Soal) + pilihan kanan (Pilihan Jawaban).
/// Tiap item kiri dinilai sendiri (2 poin/item).
class JodohSoal {
  final List<String> kiri;
  final List<String> kanan;
  final String? kunciText;
  JodohSoal(this.kiri, this.kanan, {this.kunciText});
}

class UjianDocx {
  String mapel;
  String kelas;
  String judul;
  int? waktuMenit;
  String guru;
  String? jurusan;
  final List<PgSoal> pg = [];
  final List<EssaySoal> essay = [];
  final List<JodohSoal> jodoh = [];
  final Map<String, Uint8List> images = {};
  final List<String> warnings = [];
  UjianDocx({this.mapel = '', this.kelas = '', this.judul = 'Ujian', this.guru = ''});
}

class _Block {
  bool isTable = false;
  String text = '';              // teks dengan '\t' sebagai pemisah tab Word
  List<String> imgs = const [];
  List<List<List<String>>>? table;
}

class UjianDocxParser {
  static final _poin = RegExp(r'\(\s*\d+\s*(?:poin|point|skor)\s*\)', caseSensitive: false);
  static final _qEnd = RegExp(r'(\.{3}|…+|\?)\s*$');
  static final _hurufEksplisit = RegExp(r'^([a-jA-J])[.)]\s*');

  static UjianDocx parse(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final docFile = archive.files.firstWhere(
      (f) => f.name == 'word/document.xml',
      orElse: () => throw const FormatException('bukan docx'),
    );
    final xml = utf8.decode(_bytes(docFile.content));
    final u = UjianDocx();

    final rels = <String, String>{};
    for (final f in archive.files) {
      if (f.name == 'word/_rels/document.xml.rels') {
        final rx = utf8.decode(_bytes(f.content));
        for (final m in RegExp(r'Id="([^"]+)"[^>]*Target="([^"]+)"').allMatches(rx)) {
          var t = m.group(2)!;
          if (t.startsWith('../')) t = t.substring(3);
          rels[m.group(1)!] = t;
        }
      }
    }
    for (final f in archive.files) {
      if (f.name.startsWith('word/media/')) {
        u.images[f.name.substring('word/'.length)] = _bytes(f.content);
      }
    }

    final body = RegExp(r'<w:body>(.*)</w:body>', dotAll: true).firstMatch(xml)?.group(1) ?? xml;
    final blocks = <_Block>[];
    int cursor = 0;
    for (final tbl in RegExp(r'<w:tbl>.*?</w:tbl>', dotAll: true).allMatches(body)) {
      _addTextParts(blocks, body.substring(cursor, tbl.start), rels);
      blocks.add(_Block()
        ..isTable = true
        ..table = _parseTable(tbl.group(0)!));
      cursor = tbl.end;
    }
    _addTextParts(blocks, body.substring(cursor), rels);

    _extract(blocks, u);
    return u;
  }

  /// Ambil teks per paragraf. TAB Word (<w:tab/>) diubah jadi '\t'
  /// supaya opsi auto-numbering bisa dipisah.
  static void _addTextParts(List<_Block> blocks, String part, Map<String, String> rels) {
    if (part.trim().isEmpty) return;
    for (final pm in RegExp(r'<w:p [^>]*>.*?</w:p>|<w:p>.*?</w:p>|<w:p/>').allMatches(part)) {
      final p = pm.group(0)!;
      final buf = StringBuffer();
      for (final m in RegExp(r'<w:tab/>|<w:t[^>]*>([^<]*)</w:t>').allMatches(p)) {
        if (m.group(0) == '<w:tab/>') {
          buf.write('\t');
        } else {
          buf.write(_un(m.group(1) ?? ''));
        }
      }
      final imgs = RegExp(r'r:embed="([^"]+)"|r:id="(rId\d+)"')
          .allMatches(p)
          .map((m) => rels[(m.group(1) ?? m.group(2))!] ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      final t = buf.toString().trim();
      if (t.isEmpty && imgs.isEmpty) continue;
      blocks.add(_Block()..isTable = false..text = t..imgs = imgs);
    }
  }

  static List<List<List<String>>> _parseTable(String t) {
    final rows = <List<List<String>>>[];
    for (final r in RegExp(r'<w:tr[ >].*?</w:tr>', dotAll: true).allMatches(t)) {
      final cells = <List<String>>[];
      for (final c in RegExp(r'<w:tc[ >].*?</w:tc>|<w:tc/>', dotAll: true).allMatches(r.group(0)!)) {
        final lines = <String>[];
        for (final p in RegExp(r'<w:p [^>]*>.*?</w:p>|<w:p>.*?</w:p>|<w:p/>').allMatches(c.group(0)!)) {
          final txt = RegExp(r'<w:t[^>]*>([^<]*)</w:t>')
              .allMatches(p.group(0)!)
              .map((m) => _un(m.group(1) ?? ''))
              .join('')
              .trim();
          if (txt.isNotEmpty) lines.add(txt);
        }
        cells.add(lines);
      }
      if (cells.isNotEmpty) rows.add(cells);
    }
    return rows;
  }

  static void _extract(List<_Block> blocks, UjianDocx u) {
    String sec = 'meta'; // meta|pg|jawaban-pg|jodoh|essay|kunci
    String? curQ;
    List<String> curOpsi = [];
    Map<String, String> curHuruf = {};
    String? curImg;

    void flushPg() {
      if (curQ != null && curOpsi.length >= 2) {
        u.pg.add(PgSoal(curQ!, curOpsi, Map.from(curHuruf), null, curImg));
      }
      curQ = null;
      curOpsi = [];
      curHuruf = {};
      curImg = null;
    }

    void consumeOpsi(String raw) {
      final segs = raw.split('\t').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      for (final seg in segs) {
        String txt = seg;
        String? lbl;
        final m = _hurufEksplisit.firstMatch(seg);
        if (m != null) {
          lbl = m.group(1)!.toUpperCase();
          txt = seg.substring(m.end).trim();
        }
        if (txt.isEmpty || _isDots(txt)) continue;
        lbl ??= _nextUnused(curHuruf);
        // Kalau huruf sudah dipakai, cari slot kosong berikutnya (auto-numbering)
        if (curHuruf.containsKey(lbl)) lbl = _nextUnused(curHuruf);
        curHuruf[lbl] = txt;
      }
      curOpsi
        ..clear()
        ..addAll((curHuruf.keys.toList()..sort()).map((k) => curHuruf[k]!));
    }

    bool isSoalBaru(String line) => _poin.hasMatch(line) || _qEnd.hasMatch(line);

    for (final b in blocks) {
      if (b.isTable) {
        if (sec == 'jodoh') {
          _parseJodohTable(b, u);
        } else if (sec == 'essay') {
          _parseEssayTable(b, u);
        }
        continue;
      }

      final lineTab = b.text;
      final line = lineTab.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (line.isEmpty) continue;
      final up = line.toUpperCase();

      // ── KUNCI JAWABAN ──
      if (sec == 'kunci') {
        final mk = RegExp(r'^(\d{1,3})\s*[.):=]\s*([A-J])\b', caseSensitive: false).firstMatch(line);
        if (mk != null) {
          final n = int.tryParse(mk.group(1)!) ?? 0;
          if (n >= 1 && n <= u.pg.length) u.pg[n - 1].kunci = mk.group(2)!.toUpperCase();
        }
        continue;
      }

      // ── META ──
      final mMapel = RegExp(r'^Mata\s*Pelajaran\s*[:\-]\s*(.+)$', caseSensitive: false).firstMatch(line);
      if (mMapel != null) { u.mapel = _clean(mMapel.group(1)!); continue; }
      final mKelas = RegExp(r'^Kelas\s*(?:/\s*Konsentrasi\s*Keahlian)?\s*[:\-]\s*(.+)$', caseSensitive: false).firstMatch(line);
      if (mKelas != null) { u.kelas = _normKelas(mKelas.group(1)!); continue; }
      final mJur = RegExp(r'^Program\s*Keahlian\s*[:\-]\s*(.+)$', caseSensitive: false).firstMatch(line);
      if (mJur != null && u.jurusan == null) {
        final v = _clean(mJur.group(1)!);
        if (v.toUpperCase() != 'SEMUA JURUSAN') u.jurusan = v.toUpperCase();
        continue;
      }
      final mWaktu = RegExp(r'^Waktu\s*[:\-]\s*(\d{1,3})\s*menit', caseSensitive: false).firstMatch(line);
      if (mWaktu != null) { u.waktuMenit = int.tryParse(mWaktu.group(1)!); continue; }
      final mGuru = RegExp(r'^Guru\s*Mata\s*Pelajaran\s*[:\-]\s*(.+)$', caseSensitive: false).firstMatch(line);
      if (mGuru != null) { u.guru = _clean(mGuru.group(1)!); continue; }

      // ── SEKSI ──
      if (RegExp(r'^PILIHAN\s+GANDA', caseSensitive: false).hasMatch(line)) {
        flushPg(); sec = 'pg'; continue;
      }
      if (RegExp(r'^JAWABAN\s+PILIHAN\s+GANDA', caseSensitive: false).hasMatch(line) ||
          RegExp(r'^LEMBAR\s+JAWABAN', caseSensitive: false).hasMatch(line)) {
        flushPg(); sec = 'jawaban-pg'; continue;
      }
      if (RegExp(r'MENJODOHKAN|JODOHKAN|MENCOCOKKAN', caseSensitive: false).hasMatch(line)) {
        flushPg(); sec = 'jodoh'; continue;
      }
      if (RegExp(r'KUNCI\s+JAWABAN', caseSensitive: false).hasMatch(line)) {
        flushPg(); sec = 'kunci'; continue;
      }
      if (RegExp(r'^(ESSAY\s*(URAIAN|SINGKAT)?|URAIAN)\s*:?\s*$', caseSensitive: false).hasMatch(line) &&
          !RegExp(r'JAWABAN\s*:').hasMatch(line)) {
        flushPg(); sec = 'essay'; continue;
      }

      // Judul ujian
      if (u.judul == 'Ujian' && sec == 'meta' &&
          RegExp(r'ASESMEN|SUMATIF|ULANGAN|UJIAN|TRY\s*OUT|PENILAIAN', caseSensitive: false).hasMatch(up) &&
          !up.contains('PILIHAN GANDA')) {
        u.judul = _clean(line);
        continue;
      }

      // ── ISI PER SEKSI ──
      if (sec == 'pg') {
        if (line.startsWith('Pilihlah') || line.startsWith('Nama Siswa')) continue;
        if (isSoalBaru(line)) {
          flushPg();
          curQ = _clean(line.replaceAll(_poin, '').replaceFirst(RegExp(r'^\d+[.)]\s*'), '').trim());
          curImg = b.imgs.isNotEmpty ? b.imgs.first : null;
          continue;
        }
        if (curQ != null) {
          if (b.imgs.isNotEmpty && curImg == null) curImg = b.imgs.first;
          consumeOpsi(lineTab);
        }
        continue;
      }

      if (sec == 'essay') {
        if (line.startsWith('Jawaban') || line.startsWith('SCORE')) { flushPg(); continue; }
        if (_poin.hasMatch(line) || _qEnd.hasMatch(line)) {
          var t = line.replaceAll(_poin, '').trim();
          // buang prefix "Essay nomor 1:" / "1." / "Essay:" di awal
          t = t.replaceFirst(RegExp(r'^(?:Essay|Uraian)\s*(?:nomor\s*)?\d*\s*[.):-]?\s*', caseSensitive: false), '').trim();
          t = t.replaceFirst(RegExp(r'^\d+[.)]\s*'), '').trim();
          if (t.length > 6 && RegExp('[A-Za-zÀ-ÿ]').hasMatch(t)) u.essay.add(EssaySoal(t));
        }
        continue;
      }
    }
    flushPg();

    // ── VALIDASI & LAPORAN ──
    if (u.mapel.isEmpty) u.warnings.add('Nama Mata Pelajaran tidak terdeteksi');
    if (u.kelas.isEmpty) u.warnings.add('Kelas tidak terdeteksi di dokumen');
    if (u.pg.isEmpty && u.essay.isEmpty && u.jodoh.isEmpty) {
      u.warnings.add('Tidak ada soal yang terdeteksi');
    }
    if (u.jodoh.isNotEmpty) {
      final jml = u.jodoh.fold<int>(0, (s, j) => s + j.kiri.length);
      u.warnings.add('$jml item menjodohkan terdeteksi');
      final tanpaKunci = u.jodoh.where((j) => j.kunciText == null).length;
      if (tanpaKunci > 0) {
        u.warnings.add('$tanpaKunci grup jodoh tanpa kunci — isi via menu edit soal');
      }
    }
    if (u.pg.isNotEmpty && !u.pg.any((p) => p.kunci != null)) {
      u.warnings.add('Kunci jawaban PG tidak terdeteksi — isi via menu “Isi Kunci Jawaban”');
    }
  }

  /// Tabel jodoh: header "Soal | Pilihan Jawaban | Jawaban".
  /// Tiap baris data = 1 item kiri; kolom ke-2 = opsi kanan.
  static void _parseJodohTable(_Block b, UjianDocx u) {
    final table = b.table;
    if (table == null) return;
    final kiri = <String>[];
    final kanan = <String>[];
    final pasangan = <String>[];
    for (final r in table) {
      if (r.length < 2) continue;
      final head = r[0].join(' ').trim().toUpperCase();
      if (head == 'SOAL' || head == 'PERTANYAAN') continue;
      final soal = r[0]
          .where((l) => !_isDots(l))
          .join(' ')
          .trim();
      final soalBersih = soal.replaceAll(_poin, '').trim();
      if (soalBersih.isEmpty) continue;
      kiri.add(soalBersih);

      final opsiTeks = r[1].where((l) => !_isDots(l)).join(' ').trim();
      for (final seg in opsiTeks.split(RegExp(r'[,;]|\s{2,}')).map((s) => s.trim())) {
        var o = seg.replaceAll(_hurufEksplisit, '').trim();
        o = o.replaceAll(_poin, '').trim();
        if (o.isNotEmpty && !kanan.contains(o)) kanan.add(o);
      }

      final jawabTeks = r.length > 2
          ? r[2].where((l) => !_isDots(l)).join(' ').trim()
          : '';
      final mJwb = RegExp(r'([A-Ja-j])').firstMatch(jawabTeks);
      if (mJwb != null) {
        pasangan.add('${kiri.length}-${mJwb.group(1)!.toUpperCase()}');
      }
    }
    if (kiri.isNotEmpty && kanan.isNotEmpty) {
      u.jodoh.add(JodohSoal(
        kiri,
        kanan,
        kunciText: pasangan.isEmpty ? null : pasangan.join(', '),
      ));
    }
  }

  /// Tabel essay (header mengandung PERTANYAAN / URAIAN, tanpa "PILIHAN JAWABAN").
  static void _parseEssayTable(_Block b, UjianDocx u) {
    final table = b.table;
    if (table == null) return;
    final joined = table.expand((r) => r).expand((c) => c).join(' ').toUpperCase();
    if (joined.contains('PILIHAN JAWABAN')) return; // ini tabel jodoh
    if (!joined.contains('PERTANYAAN') && !joined.contains('URAIAN')) return;
    for (final r in table) {
      if (r.isEmpty) continue;
      for (final line in r.first) {
        final t = line.replaceAll(_poin, '').trim();
        if (t.length > 8 && RegExp('[A-Za-zÀ-ÿ]').hasMatch(t) && !t.startsWith('https')) {
          u.essay.add(EssaySoal(t));
        }
      }
    }
  }

  static bool _isDots(String s) => RegExp(r'^[\s.…_—-]+$').hasMatch(s.trim()) || RegExp(r'^\?(\s*\?)*$').hasMatch(s.trim());

  static String _nextUnused(Map<String, String> huruf) {
    for (final c in ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J']) {
      if (!huruf.containsKey(c)) return c;
    }
    return 'J';
  }

  static String _normKelas(String raw) {
    // Buang terjemahan tingkat dalam tanda kurung ATAU setelah slash:
    // "X/Sepuluh", "X (Sepuluh)", "XI/Sebelas", "XII (Dua Belas)"
    var t = raw.replaceAll(
        RegExp(r'[/]?\s*\(?(Sepuluh|Sebelas|Dua Belas|Satu|Dua|Tiga)\)?', caseSensitive: false),
        '');
    t = t.replaceAll('–', '-').trim();
    final m = RegExp(r'^(X{1,3}|XI{0,2}|I{1,3})\s*[-/]?\s*([A-Z]{2,6}(?:\s*\d+)?)', caseSensitive: false)
        .firstMatch(t.toUpperCase());
    if (m != null) return '${m.group(1)} ${m.group(2)}'.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    final single = RegExp(r'^(X{1,3}|I{1,3})\b', caseSensitive: false).firstMatch(t.trim());
    if (single != null) return single.group(1)!.toUpperCase();
    return _clean(t);
  }

  static String _clean(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('…', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _un(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll(RegExp(r'_x[0-9A-Fa-f]{4}_'), '');
}

Uint8List _bytes(dynamic c) {
  if (c == null) return Uint8List(0);
  try {
    return Uint8List.fromList(List<int>.from(c as Iterable));
  } catch (_) {
    return Uint8List(0);
  }
}
