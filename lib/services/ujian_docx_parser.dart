import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

class PgSoal {
  final String soal;
  final List<String> opsi;
  final Map<String, String> hurufOpsi; // huruf -> teks (hasil deteksi)
  String? kunci;
  final String? imgPath;
  PgSoal(this.soal, this.opsi, this.hurufOpsi, this.kunci, this.imgPath);
}

class JodohSoal {
  final String soal;
  final List<String> opsi;
  JodohSoal(this.soal, this.opsi);
}

class EssaySoal {
  final String soal;
  EssaySoal(this.soal);
}

class UjianDocx {
  String mapel;
  String kelas;
  String judul;
  int? waktuMenit;
  String guru;
  String? jurusan;
  final List<PgSoal> pg = [];
  final List<JodohSoal> jodoh = [];
  final List<EssaySoal> essay = [];
  final Map<String, Uint8List> images = {};
  final List<String> warnings = [];
  UjianDocx({this.mapel = '', this.kelas = '', this.judul = 'Ujian', this.guru = ''});
}

class _Block {
  bool isTable = false;
  String text = '';
  List<String> imgs = const [];
  List<List<List<String>>>? table;
}

/// Parser naskah ujian .docx — mendukung (minimal) 2 style:
///  A) satu baris penuh per soal: "...?a. A. x b. B. y c. C. z ..."
///  B) list mode: soal = baris "...." / "?" lalu opsi di paragraf berikutnya,
///     huruf a/b/c auto-numbering word (tidak ada di teks), d/e nempel eksplisit,
///     plus tabel PERTANYAAN|PILIHAN JAWABAN utk esai/jodoh.
class UjianDocxParser {
  static final _qEnd = RegExp(r'(\.{3}|…+|\?)\s*$');
  static final _explOpt = RegExp(r'([a-fA-F])[.)]\s+(?=[A-Z])');
  static final _combined = RegExp(r'([a-e])[.)]\s*([A-F])[.)]');

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

  // ---------------- block helpers ---------------
  static void _addTextParts(List<_Block> blocks, String part, Map<String, String> rels) {
    if (part.trim().isEmpty) return;
    for (final pm in RegExp(r'<w:p [^>]*>.*?</w:p>|<w:p>.*?</w:p>|<w:p/>').allMatches(part)) {
      final p = pm.group(0)!;
      final txt = RegExp(r'<w:t[^>]*>([^<]*)</w:t>')
          .allMatches(p)
          .map((m) => _un(m.group(1) ?? ''))
          .join('');
      final imgs = RegExp(r'r:embed="([^"]+)"|r:id="(rId\d+)"')
          .allMatches(p)
          .map((m) => rels[(m.group(1) ?? m.group(2))!] ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      final t = txt.trim();
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
        final raw = c.group(0)!;
        for (final p in RegExp(r'<w:p [^>]*>.*?</w:p>|<w:p>.*?</w:p>|<w:p/>').allMatches(raw)) {
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

  // ---------------- mesin eksrtraksi ----------------
  static void _extract(List<_Block> blocks, UjianDocx u) {
    String sec = 'meta'; // meta|pg|jodoh|essay|kunci
    // list-mode state
    String? curQ;
    List<String> curOpsi = [];
    Map<String, String> curHuruf = {};
    List<String> curAll = [];
    String? curImg;

    void flushPg() {
      if (curQ != null && curOpsi.length >= 2) {
        u.pg.add(PgSoal(curQ!, curOpsi, curHuruf, null, curImg));
      }
      curQ = null;
      curOpsi = [];
      curHuruf = {};
      curAll = [];
      curImg = null;
    }


    for (final b in blocks) {
      if (b.isTable) {
        _handleTable(b, u,
            essaySink: (t) => u.essay.add(EssaySoal(t)),
            onJodoh: (it, opsi) => u.jodoh.add(JodohSoal(it, opsi)));
        if (sec == 'pg') flushPg();
        continue;
      }
      final line = b.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (line.isEmpty) continue;
      final up = line.toUpperCase();

      if (sec == 'kunci') {
        final mk = RegExp(r'^(\d{1,3})\s*[.):=]\s*([A-J])\b', caseSensitive: false).firstMatch(line);
        if (mk != null) {
          final n = int.tryParse(mk.group(1)!) ?? 0;
          if (n >= 1 && n <= u.pg.length) {
            u.pg[n - 1].kunci = mk.group(2)!.toUpperCase();
          }
        }
        continue;
      }

      final mMapel = RegExp(r'^Mata\s*Pelajaran\s*[:\-]\s*(.+)$', caseSensitive: false).firstMatch(line);
      if (mMapel != null) {
        u.mapel = _clean(mMapel.group(1)!);
        continue;
      }
      final mKelas = RegExp(r'^Kelas\s*(/?\s*Kompetensi[^:]*)?[:\-]\s*(.+)$', caseSensitive: false).firstMatch(line);
      if (mKelas != null) {
        u.kelas = _normKelas(mKelas.group(2)!);
        continue;
      }
      final mJur = RegExp(r'^Kompetensi\s*Keahlian\s*[:\-]\s*(.+)$', caseSensitive: false).firstMatch(line);
      if (mJur != null && u.jurusan == null) {
        u.jurusan = _clean(mJur.group(1)!).toUpperCase();
        continue;
      }
      final mWaktu = RegExp(r'^Waktu\s*[:\-]\s*(\d{1,3})\s*menit', caseSensitive: false).firstMatch(line);
      if (mWaktu != null) {
        u.waktuMenit = int.tryParse(mWaktu.group(1)!);
        continue;
      }
      final mGuru = RegExp(r'^Guru\s*Mata\s*Pelajaran\s*[:\-]\s*(.+)$', caseSensitive: false).firstMatch(line);
      if (mGuru != null) {
        u.guru = _clean(mGuru.group(1)!);
        continue;
      }
      if (RegExp(r'^(PILIHAN|LEMBAR|PETUNJUK.*PILIHAN)\s+GANDA', caseSensitive: false).hasMatch(line) ||
          (up.contains('PILIHAN GANDA') && !up.startsWith('JAWABAN') && sec != 'pg')) {
        flushPg();
        sec = 'pg';
        continue;
      }
      if (RegExp(r'MENJODOHKAN|JODOHKAN|MENJODOH|MENCOCOKKAN', caseSensitive: false).hasMatch(line)) {
        flushPg();
        sec = 'jodoh';
        continue;
      }
      if (RegExp(r'ESSAY|URAIAN', caseSensitive: false).hasMatch(up)) {
        if (up.contains('KUNCI')) {
          flushPg();
          sec = 'kunci';
          continue;
        }
        flushPg();
        sec = 'essay';
        final m = RegExp(r'^(?:[A-E]\.?\s*)?(?:ESSAY|URAIAN|ESSAY\s+(?:SINGKAT|URAIAN))\s*[:\-]?\s*(.*)$', caseSensitive: false).firstMatch(line);
        final extra = (m?.group(1) ?? '').trim();
        if (extra.isNotEmpty && _looksLikeEssay(extra)) u.essay.add(EssaySoal(extra));
        continue;
      }
      if (up.contains('KUNCI JAWABAN')) {
        flushPg();
        sec = 'kunci';
        continue;
      }
      if (u.judul == 'Ujian' && sec == 'meta' &&
          RegExp(r'PENILAIAN|SUMATIF|ULANGAN|UJIAN|TRY\s*OUT|ASESMEN|ASAT|ASUMPTIF', caseSensitive: false).hasMatch(up) &&
          !up.contains('PILIHAN GANDA')) {
        u.judul = _clean(line);
        continue;
      }

      if (sec == 'pg') {
        if ((line.contains('Pilihlah') && line.length < 90) || line.startsWith('Nama Siswa')) continue;
        // MODE A: 1 baris = 1 soal lengkap dgn pasangan 'a. A.'
        final cmb = _combined.allMatches(line).length;
        if (cmb >= 2) {
          flushPg();
          _parsePgCombined(line, b, u);
          continue;
        }
        // MODE B: list
        if (_qEnd.hasMatch(line)) {
          flushPg();
          curQ = _clean(line.replaceFirst(RegExp(r'^\d+[.)]\s*'), '').trim());
          curImg = b.imgs.isNotEmpty ? b.imgs.first : null;
          continue;
        }
        if (curQ != null) {
          if (b.imgs.isNotEmpty && curImg == null) curImg = b.imgs.first;
          _consumeOptLine(line, curOpsi, curHuruf);
          if (curOpsi.length >= 5) flushPg();
        }
        continue;
      } else if (sec == 'essay') {
        var t = line.replaceFirst(RegExp(r'^\d+[.)]\s*'), '').trim();
        if (_looksLikeEssay(t)) u.essay.add(EssaySoal(t));
      } else if (sec == 'jodoh') {
        if (_qEnd.hasMatch(line) && line.length > 18) {
          u.jodoh.add(JodohSoal(line, const []));
        }
      }
    }
    flushPg();

    // ---- dedup & laporan kualitas ----
    final uniq = <String, PgSoal>{};
    String norm(PgSoal p) => p.soal.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final list = <PgSoal>[];
    for (final p in u.pg) {
      final key = norm(p);
      final idx = list.indexWhere((e) {
        final ek = norm(e);
        return ek == key || ek.startsWith(key) || key.startsWith(ek);
      });
      if (idx < 0) {
        list.add(p);
      } else {
        final ex = list[idx];
        if (p.opsi.length > ex.opsi.length || (p.kunci != null && ex.kunci == null)) {
          final nn = p.kunci ?? ex.kunci;
          final opsi = p.opsi.length >= ex.opsi.length ? p.opsi : ex.opsi;
          list[idx] = PgSoal(
              p.soal.length >= ex.soal.length ? p.soal : ex.soal,
              opsi,
              opsi == p.opsi ? p.hurufOpsi : ex.hurufOpsi,
              nn,
              p.imgPath ?? ex.imgPath);
        }
      }
    }
    final before = u.pg.length;
    u.pg
      ..clear()
      ..addAll(list);
    if (u.pg.length < before) {
      u.warnings.add('${before - u.pg.length} soal duplikat/ganda telah digabung');
    }
    final tanpaOpsi = u.pg.where((p) => p.opsi.length < 2).length;
    if (tanpaOpsi > 0) u.warnings.add('$tanpaOpsi soal PG terdeteksi tanpa opsi — periksa sebelum disimpan');
    if (u.mapel.isEmpty) u.warnings.add('Nama Mata Pelajaran tidak terdeteksi di dokumen');
    if (u.kelas.isEmpty) u.warnings.add('Kelas tidak terdeteksi di dokumen');
    if (u.pg.isEmpty && u.jodoh.isEmpty && u.essay.isEmpty) {
      u.warnings.add('Tidak ada soal yang terdeteksi');
    }
    final adaKunci = u.pg.any((p) => p.kunci != null);
    if (!adaKunci && u.pg.isNotEmpty) {
      u.warnings.add('Kunci jawaban PG tidak terdeteksi — soal masuk DRAFT, isi via menu “Isi Kunci Jawaban”');
    }

  }

  static bool _looksLikeEssay(String t) =>
      t.length > 6 &&
      !RegExp(r'^[\d.\s]+$').hasMatch(t) &&
      RegExp('[A-Za-zÀ-ÿ]').hasMatch(t) &&
      RegExp(r'^(sebutkan|jelaskan|uraikan|bandingkan|mengapa|apa|bagaimana|carakan|tuliskan|tentukan|analisis|hitung|ceritakan|menurut|diantaranya|berikut)', caseSensitive: false).hasMatch(t.replaceFirst(RegExp(r'^["\-–—•]+\s*'), '')) || t.length > 20;

  /// mode B: satukan potongan opsi (termasuk yang nempel 'sematad. Politik')
  static void _consumeOptLine(String line, List<String> opsi, Map<String, String> huruf) {
    final hits = _explOpt.allMatches(line).toList();
    if (hits.isEmpty) {
      final t = line.trim();
      if (t.isNotEmpty) huruf[_nextUnused(huruf)] = t;
    } else {
      // segmen kiri dari potongan pertama = opsi implicit (a / b / c ...)
      var firstLeft = line.substring(0, hits.first.start).trim();
      // buang huruf nyempil: 'Ekonomi sematad' + 'd. Politik...'
      final stray = hits.first.group(1)!;
      if (firstLeft.length > 2 &&
          firstLeft.toLowerCase().endsWith(stray.toLowerCase())) {
        firstLeft = firstLeft.substring(0, firstLeft.length - 1).trim();
      }
      if (firstLeft.isNotEmpty) {
        huruf[_nextUnused(huruf)] = firstLeft;
      }
      for (var i = 0; i < hits.length; i++) {
        final lbl = hits[i].group(1)!.toUpperCase();
        final end = i + 1 < hits.length ? hits[i + 1].start : line.length;
        var body = line.substring(hits[i].start, end).trim();
        body = body.replaceFirst(RegExp(r'^[a-fA-F][.)]\s*'), '').trim();
        if (body.isNotEmpty) huruf[lbl] = body;
      }
    }
    opsi
      ..clear()
      ..addAll((huruf.keys.toList()..sort()).map((k) => huruf[k]!)
          .toList());
  }

  static String _nextUnused(Map<String, String> huruf) {
    for (final c in ['A', 'B', 'C', 'D', 'E', 'F']) {
      if (!huruf.containsKey(c)) return c;
    }
    return 'F';
  }

  /// mode A: baris penuh dengan pasangan 'a. A. ... b. B.'
  static void _parsePgCombined(String line, _Block b, UjianDocx u) {
    final ms = _combined.allMatches(line).toList();
    final first = ms.first.start;
    var q = line.substring(0, first).trim();
    q = q.replaceFirst(RegExp(r'^\d+[.)]\s*'), '').trim();
    if (q.isEmpty || q.length < 4) return;
    final opsi = <String>[];
    final huruf = <String, String>{};
    for (var i = 0; i < ms.length; i++) {
      final st = ms[i].start;
      final en = i + 1 < ms.length ? ms[i + 1].start : line.length;
      var t = line.substring(st, en);
      t = t.replaceFirst(RegExp(r'^[a-e][.)]\s*'), '').replaceFirst(RegExp(r'^[A-F][.)]\s*'), '').trim();
      if (t.isNotEmpty) {
        final ltr = String.fromCharCode(65 + i);
        opsi.add(t);
        huruf[ltr] = t;
      }
    }
    if (opsi.length >= 2) {
      u.pg.add(PgSoal(q, opsi, huruf, null, b.imgs.isNotEmpty ? b.imgs.first : null));
    }
  }

  static void _handleTable(_Block b, UjianDocx u,
      {required void Function(String) essaySink,
      required void Function(String item, List<String> opsi) onJodoh}) {
    if (b.table == null) return;
    final cells = <List<String>>[];
    for (final r in b.table!) {
      for (final c in r) {
        if (c.isNotEmpty) cells.add(c);
      }
    }
    final joined = cells.map((c) => c.join(' ')).join(' ~ ').toUpperCase();
    final hasOpsiKolom = joined.contains('PILIHAN JAWABAN');
    final hasKiri = joined.contains('SOAL') || joined.contains('PERTANYAAN') || joined.contains('Cocokkan');
    final hasPasang = joined.contains('PASANGKANLAH') || joined.contains('JODOHKANLAH');
    if (!hasOpsiKolom || !hasKiri && !hasPasang) {
      // mungkin jawabian kosong / header jawaban — lewati
      return;
    }
    final kiriLines = <String>[];
    final opsiLines = <String>[];
    for (final c in cells) {
      final txt = c.join(' ').toUpperCase();
      final isRight = txt.contains('PILIHAN JAWABAN');
      final isLeft = txt.contains('SOAL') || txt.contains('PERTANYAAN');
      final isAnswerCol =
          txt.startsWith('JAWABAN') && !isRight && !isLeft; // kolom isian siswa (1……)
      int from = 0;
      for (; from < c.length; from++) {
        final l = c[from].toUpperCase().trim();
        if (l == 'SOAL' || l == 'PERTANYAAN' || l == 'PILIHAN JAWABAN' ||
            l == 'JAWABAN' || l.startsWith('JAWABAN')) {
          continue;
        }
        break;
      }
      if (isAnswerCol) continue;
      final body = c.skip(from).where((l) => !_isDots(l) && !RegExp(r'^\d+[.…]+$').hasMatch(l.trim())).toList();
      if (isRight) {
        opsiLines.addAll(body);
      } else if (isLeft) {
        kiriLines.addAll(body);
      } else if (kiriLines.isEmpty || body.isNotEmpty) {
        // bukan kolom jawaban & bukan header → kemungkinan soal juga (tabel tanpa header jelas)
        kiriLines.addAll(body);
      }
    }
    if (kiriLines.isEmpty) return;
    final opsi = _splitOpts(opsiLines);
    if (opsi.length >= 2) {
      for (final it in kiriLines) {
        final t = it.trim();
        if (t.isEmpty || RegExp(r'^(SOAL|KUNCI)', caseSensitive: false).hasMatch(t)) continue;
        onJodoh(t, opsi);
      }
    } else {
      final joinedHeader =
          (b.table!.expand((r) => r).expand((c) => c).join(' ').toUpperCase());
      final isEssayTable = joinedHeader.contains('PERTANYAAN') ||
          joinedHeader.contains('ESSAY') ||
          joinedHeader.contains('URAIAN');
      if (isEssayTable) {
        for (final it in kiriLines) {
          final t = it.trim();
          if (t.length > 8 && RegExp('[A-Za-zÀ-ÿ]').hasMatch(t) && !t.startsWith('https')) {
            essaySink(t);
          }
        }
      }
    }
  }

  static bool _isDots(String s) => RegExp(r'^[\s.…_—-]+$').hasMatch(s.trim());

  static List<String> _splitOpts(List<String> lines) {
    final out = <String>[];
    for (final raw in lines) {
      var t = raw.trim();
      if (t.isEmpty) continue;
      final pos = <int, String>{};
      for (final mm in RegExp(r'([A-J])\s*[.)]\s+(?=[A-Z])').allMatches(t)) {
        pos.putIfAbsent(mm.start, () => mm.group(1)!);
      }
      final ps = pos.keys.toList()..sort();
      if (ps.length >= 2) {
        final pre = t.substring(0, ps.first).replaceAll(RegExp(r'^PILIHAN JAWABAN\s*', caseSensitive: false), '').trim();
        if (pre.length > 1) {
          final first = pos[ps.first]!;
          final prev = String.fromCharCode(first.codeUnitAt(0) - 1);
          out.add('$prev. $pre');
        }
        for (var i = 0; i < ps.length; i++) {
          final start = ps[i];
          final end = i + 1 < ps.length ? ps[i + 1] : t.length;
          final body = t.substring(start, end).trim();
          final pure = body.replaceFirst(RegExp(r'^[A-J][.)]\s*'), '').trim();
          if (pure.isNotEmpty) out.add('${pos[start]}. $pure');
        }
      } else {
        if (!_isDots(t)) out.add(t);
      }
    }
    return out;
  }

  static String _normKelas(String raw) {
    var t = raw.replaceAll(RegExp(r'\((Sebelas|Dua Belas|Sepuluh|Satu|Dua|Tiga|Empat|Lima|Enam)\)', caseSensitive: false), '');
    t = t.replaceAll('–', '-');
    final m = RegExp(r'(X{1,3}|XI{0,2}|I{1,3})\s*[-/]?\s*([A-Z]{2,6}(?:\s*\d+)?)', caseSensitive: false).firstMatch(t.toUpperCase());
    if (m != null) {
      return '${m.group(1)} ${m.group(2)}'.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    }
    final mTunggal = RegExp(r'^(X{1,3}|I{1,3})\b', caseSensitive: false).firstMatch(t.trim());
    if (mTunggal != null) return mTunggal.group(1)!.toUpperCase();
    return _clean(raw);
  }

  static String _clean(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('…', '')
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
