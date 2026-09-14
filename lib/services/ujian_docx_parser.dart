import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

class PgSoal {
  final String soal;
  final List<String> opsi; // teks opsi TANPA label
  String? kunci;           // huruf 'A'..'E' kalau ada kunci
  final String? imgPath;
  PgSoal(this.soal, this.opsi, this.kunci, this.imgPath);
}

class JodohSoal {
  final String soal;
  final List<String> opsi; // full 'A. xxx'
  JodohSoal(this.soal, this.opsi);
}

class EssaySoal {
  final String soal;
  EssaySoal(this.soal);
}

class UjianDocx {
  String mapel;
  String kelas;
  int? tingkat;
  String judul;
  int? waktuMenit;
  String guru;
  String? jurusan;
  final List<PgSoal> pg = [];
  final List<JodohSoal> jodoh = [];
  final List<EssaySoal> essay = [];
  final Map<String, Uint8List> images = {};
  final List<String> warnings = [];
  UjianDocx(
      {this.mapel = '',
      this.kelas = '',
      this.judul = 'Ujian',
      this.guru = '',
      this.tingkat});
}

/// Blok dokumen urut: paragraf teks atau tabel.
class _Block {
  bool isTable = false;
  String text = '';
  List<String> imgs = const [];
  List<List<List<String>>>? table; // rows -> cells -> paragraph lines
}

class UjianDocxParser {
  static final _optMarker = RegExp(r'(?<![a-zA-Z])([a-eA-E])\s*\.\s*');
  static final _label = RegExp(r'^\s*([A-Ja-j])[\.\)]\s*');

  static UjianDocx parse(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final docFile = archive.files.firstWhere(
      (f) => f.name == 'word/document.xml',
      orElse: () => throw FormatException('bukan docx'),
    );
    final xml = utf8.decode(docFile.readBytes() ?? const []);
    final u = UjianDocx();

    // rels rId -> media path
    final rels = <String, String>{};
    for (final f in archive.files) {
      if (f.name == 'word/_rels/document.xml.rels') {
        final rx = utf8.decode(f.readBytes() ?? const []);
        for (final m in RegExp(r'Id="([^"]+)"[^>]*Target="([^"]+)"').allMatches(rx)) {
          var t = m.group(2)!;
          if (t.startsWith('../')) t = t.substring(3);
          rels[m.group(1)!] = t;
        }
      }
    }
    for (final f in archive.files) {
      if (f.name.startsWith('word/media/')) {
        u.images[f.name.substring('word/'.length)] =
            f.readBytes() ?? Uint8List(0);
      }
    }

    // pisah tubuh: teks vs tabel, berurutan
    final body = RegExp(r'<w:body>(.*)</w:body>', dotAll: true).firstMatch(xml)?.group(1) ?? xml;
    final blocks = <_Block>[];
    // selang-seling: teks non-tabel dan tabel, urut
    int cursor = 0;
    for (final tbl in RegExp(r'<w:tbl>.*?</w:tbl>', dotAll: true).allMatches(body)) {
      _addTextParts(blocks, body.substring(cursor, tbl.start), rels);
      final t = _Block()..isTable = true;
      t.table = _parseTable(tbl.group(0)!);
      blocks.add(t);
      cursor = tbl.end;
    }
    _addTextParts(blocks, body.substring(cursor), rels);

    _extract(blocks, u);
    return u;
  }

  static void _addTextParts(List<_Block> blocks, String part, Map<String, String> rels) {
    if (part.trim().isEmpty) return;
    for (final pm in RegExp(r'<w:p [^>]*>.*?</w:p>|<w:p>.*?</w:p>|<w:p/>').allMatches(part)) {
      final p = pm.group(0)!;
      final txt = RegExp(r'<w:t[^>]*>([^<]*)</w:t>')
          .allMatches(p)
          .map((m) => _un(m.group(1) ?? ''))
          .join('');
      final imgs = RegExp(r'r:embed="([^"]+)"')
          .allMatches(p)
          .map((m) => rels[m.group(1)!] ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      if (txt.trim().isEmpty && imgs.isEmpty) continue;
      blocks.add(_Block()
        ..isTable = false
        ..text = txt.trim()
        ..imgs = imgs);
    }
  }

  static List<List<List<String>>> _parseTable(String t) {
    final rows = <List<List<String>>>[];
    for (final r in RegExp(r'<w:tr[ >].*?</w:tr>').allMatches(t)) {
      final cells = <List<String>>[];
      for (final c in RegExp(r'<w:tc[ >].*?</w:tc>').allMatches(r.group(0)!)) {
        final lines = <String>[];
        for (final p in RegExp(r'<w:p[ >].*?</w:p>|<w:p/>').allMatches(c.group(0)!)) {
          final txt = RegExp(r'<w:t[^>]*>([^<]*)</w:t>')
              .allMatches(p.group(0)!)
              .map((m) => _un(m.group(1) ?? ''))
              .join('')
              .trim();
          if (txt.isNotEmpty) lines.add(txt);
        }
        cells.add(lines);
      }
      rows.add(cells);
    }
    return rows;
  }

  static void _extract(List<_Block> blocks, UjianDocx u) {
    String sec = 'meta'; // meta | pg | jodoh | essay | kunci
    for (final b in blocks) {
      if (b.isTable) {
        _handleTable(b, u, sec);
        continue;
      }
      final line = b.text.replaceAll(RegExp(r'\s+', multiLine: true), ' ').trim();
      if (line.isEmpty) continue;
      final up = line.toUpperCase();

      // meta
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
      if (RegExp(r'^(PILIHAN\s+GANDA)', caseSensitive: false).hasMatch(line)) {
        sec = 'pg';
        continue;
      }
if (RegExp(r'MENJODOHKAN|JODOHKAN|MENJODOH', caseSensitive: false).hasMatch(line)) {
        sec = 'jodoh';
        continue;
      }
      if (RegExp(r'ESSAY|URAIAN', caseSensitive: false).hasMatch(up)) {
        sec = 'essay';
        final m = RegExp(r'^[A-E]?\.?\s*(?:ESSAY|URAIAN)\s*[:\-]?\s*(.+)?$', caseSensitive: false).firstMatch(line);
        final extra = (m?.group(1) ?? '').trim();
        if (extra.isNotEmpty && extra.length > 6) u.essay.add(EssaySoal(extra));
        continue;
      }
      if (up.contains('KUNCI JAWABAN')) {
        sec = 'kunci';
        continue;
      }
      // judul: baris pertama yang bukan kop & meta
      if (u.judul == 'Ujian' && sec == 'meta' &&
          RegExp(r'PENILAIAN|SUMATIF|ULANGAN|UJIAN|TRY\s*OUT|ASESMEN', caseSensitive: false).hasMatch(up) &&
          !up.contains('PILIHAN GANDA')) {
        u.judul = _clean(line);
        continue;
      }

      if (sec == 'pg') {
        if (!line.contains('Pilihlah') && !line.startsWith('Nama Siswa')) {
          _parsePgLine(line, b, u);
        }
      } else if (sec == 'essay') {
        var t = line.replaceFirst(RegExp(r'^\d+[.)]\s*'), '').trim();
        if (t.length > 6) u.essay.add(EssaySoal(t));
      } else if (sec == 'kunci') {
        final mk = RegExp(r'^(\d{1,3})\s*[.):=]\s*([A-J])\b', caseSensitive: false).firstMatch(line);
        if (mk != null) {
          final n = int.tryParse(mk.group(1)!) ?? 0;
          if (n >= 1 && n <= u.pg.length) {
            u.pg[n - 1].kunci = mk.group(2)!.toUpperCase();
          }
        }
      }
    }
    if (u.mapel.isEmpty) u.warnings.add('Nama Mata Pelajaran tidak terdeteksi di dokumen');
    if (u.kelas.isEmpty) u.warnings.add('Kelas tidak terdeteksi di dokumen');
    if (u.pg.isEmpty && u.jodoh.isEmpty && u.essay.isEmpty) {
      u.warnings.add('Tidak ada soal yang terdeteksi');
    }
    final adaKunci = u.pg.any((p) => p.kunci != null);
    if (!adaKunci && u.pg.isNotEmpty) {
      u.warnings.add('Kunci jawaban PG tidak terdeteksi — soal masuk sebagai DRAFT, isi kunci per soal atau edit sebelum diaktifkan');
    }
  }

  static String _normKelas(String raw) {
    var t = raw.replaceAll(RegExp(r'\((Sebelas|Dua Belas|Sepuluh|Satu|Dua|Tiga|Empat|Lima|Enam)\)', caseSensitive: false), '');
    t = t.replaceAll('–', '-');
    final m = RegExp(r'(X{1,3}|XI{0,2}|I{1,3})\s*[-/]?\s*([A-Z]{2,6}(?:\s*\d+)?)', caseSensitive: false).firstMatch(t.toUpperCase());
    if (m != null) {
      final tingkat = m.group(1)!;
      final kode = m.group(2)!;
      return '${tingkat} $kode'.toUpperCase().replaceAll(RegExp(r'\s+'), ' ');
    }
    return _clean(raw);
  }

  static void _parsePgLine(String line, _Block b, UjianDocx u) {
    // pola umum dokumen ini: '...?a. A. opsi b. B. opsi' -> marker berpasangan 'x. A.'
    final combined = RegExp(r'([a-e])[.)]\s*([A-F])[.)]\s*');
    final cm = combined.allMatches(line).toList();
    positions:
    if (cm.length >= 2) {
      // split pakai posisi grup-1 (huruf kecil x)
      final ps = cm.map((m) => m.start).toList();
      final first = ps.first;
      var q = line.substring(0, first).trim();
      q = q.replaceFirst(RegExp(r'^\d+[.)]\s*'), '').trim();
      if (q.isEmpty || q.length < 4) {
        u.warnings.add('Soal terlewat (pertanyaan kosong): ${line.substring(0, line.length > 60 ? 60 : line.length)}');
        break positions;
      }
      final opsi = <String>[];
      for (var i = 0; i < ps.length; i++) {
        final start = cm[i].start;
        final end = i + 1 < ps.length ? ps[i + 1] : line.length;
        var t = line.substring(start, end);
        // buang 'a.' juga 'A.' di awal segmen
        t = t.replaceFirst(RegExp(r'^[a-e][.)]\s*'), '').replaceFirst(RegExp(r'^[A-F][.)]\s*'), '').trim();
        if (t.isNotEmpty) opsi.add(t);
      }
      if (opsi.length >= 2) {
        u.pg.add(PgSoal(q, opsi, null, b.imgs.isNotEmpty ? b.imgs.first : null));
      }
      break positions;
    }
    // fallback: opsi tanpa label ganda 'a. xxx b. yyy' (berbatas spasi/awal)
    final bare = RegExp(r'(^|[\s\)])([a-e])[.)]\s+');
    final bm = bare.allMatches(line).toList();
    if (bm.length >= 2) {
      final first = bm.first.start + bm.first.group(1)!.length;
      var q = line.substring(0, first).trim();
      q = q.replaceFirst(RegExp(r'^\d+[.)]\s*'), '').trim();
      final opsi = <String>[];
      for (var i = 0; i < bm.length; i++) {
        final startIdx = (bm[i].start + bm[i].group(1)!.length + (bm[i].group(2)!.length + 2)).clamp(0, line.length);
        final end = i + 1 < bm.length ? bm[i + 1].start : line.length;
        final t = line.substring(startIdx, end > startIdx ? end : startIdx).trim();
        if (t.isNotEmpty) opsi.add(t);
      }
      if (q.length >= 4 && opsi.length >= 2) {
        u.pg.add(PgSoal(q, opsi, null, b.imgs.isNotEmpty ? b.imgs.first : null));
      }
    }
  }

  static void _handleTable(_Block b, UjianDocx u, String sec) {
    if (b.table == null) return;
    // cari tabel jodoh: cell dengan 'PILIHAN JAWABAN' / 'SOAL'
    for (final row in b.table!) {
      final texts = row.map((c) => c.join(' ')).toList();
      final joined = texts.join(' ').toUpperCase();
      if (joined.contains('PILIHAN JAWABAN') || joined.contains('PASANGKANLAH') || joined.contains('JODOHKANLAH')) {
        List<String>? kiri, kanan;
        for (final cell in row) {
          final t = cell.join(' ').toUpperCase();
          if (t.contains('SOAL') && !t.contains('PILIHAN')) kiri ??= cell;
          if (t.contains('PILIHAN JAWABAN')) kanan ??= cell;
        }
        if (kiri != null && kanan != null) {
          final items = kiri.where((l) => !RegExp(r'^SOAL$', caseSensitive: false).hasMatch(l.trim())).toList();
          var opsiLines = _splitOpts(kanan.skip(1).toList());
          var firstIdx = -1;
          for (var i = 0; i < items.length; i++) {
            final it = items[i];
            if (it.trim().isEmpty) continue;
            u.jodoh.add(JodohSoal(it.trim(), opsiLines));
            firstIdx++;
          }
          if (firstIdx < 0) u.warnings.add('Tabel menjodohkan kosong');
        }
      }
    }
  }

  /// pilah 'PILIHAN JAWABAN' cell -> list 'A. xxx'
  /// teks bisa menyatu tanpa baris baru ('verifikasi...B. hak akses')
  static List<String> _splitOpts(List<String> lines) {
    final out = <String>[];
    for (final raw in lines) {
      var t = raw.trim();
      if (t.isEmpty) continue;
      // pisah pakai marker 'A.' 'B.' dst (termasuk yang nempel ke huruf sebelumnya: 'identitasB. ')
      final pos = <int, String>{};
      for (final mm in RegExp(r'([A-J])\s*[.)]\s+(?=[A-Z])').allMatches(t)) {
        pos.putIfAbsent(mm.start, () => mm.group(1)!);
      }
      final ps = pos.keys.toList()..sort();
      if (ps.length >= 2) {
        // segmen sebelum marker pertama = opsi A (sering tanpa label 'A.')
        final pre = t.substring(0, ps.first).replaceAll(RegExp(r'^PILIHAN JAWABAN\s*', caseSensitive: false), '').trim();
        if (pre.length > 1) {
          final lbl = pos[ps.first]!;
          final prev = String.fromCharCode(lbl.codeUnitAt(0) - 1);
          out.add('$prev. $pre'); // 'A. Verifikasi identitas'
        }
        for (var i = 0; i < ps.length; i++) {
          final start = ps[i];
          final end = i + 1 < ps.length ? ps[i + 1] : t.length;
          final body = t.substring(start, end).trim();
          final letter = pos[start]!;
          final pure = body.replaceFirst(RegExp(r'^[A-J][.)]\s*'), '').trim();
          if (pure.isNotEmpty) out.add('$letter. $pure');
        }
      } else {
        out.add(t);
      }
    }
    return out;
  }

  static String _clean(String s) {
    var t = s.replaceAll('&amp;', '&');
    t = RegExp(r'^[A-Z]\.\s*', caseSensitive: false).hasMatch(t) ? t : t;
    return t.replaceAll('…', '').trim();
  }

  static String _un(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");
}
