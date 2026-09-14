import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Satu sheet tabel hasil parsing. `images` memetakan id gambar (mis.
/// `word/media/image1.png`) ke bytes-nya utk yang direferensikan sel.
class ImportSheet {
  final String name;
  final List<List<String>> rows;
  /// token «IMG:path» di dalam sel -> path relatif di file docx
  final Map<String, Uint8List> images;
  const ImportSheet(this.name, this.rows, [this.images = const {}]);
}

/// Parser file spreadsheet: Excel 2003 XML (.xls dari aplikasi sekolah),
/// Office Open XML (.xlsx), dan CSV.
class SheetParser {
  static List<ImportSheet> parse(Uint8List bytes) {
    // detect by magic
    if (bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
      final archive = ZipDecoder().decodeBytes(bytes);
      final isDocx = archive.any((f) => f.name == 'word/document.xml');
      if (isDocx) return _parseDocx(archive);
      return _parseXlsx(archive);
    }
    final text = utf8.decode(bytes, allowMalformed: true);
    final trimmed = text.trimLeft();
    if (trimmed.startsWith('<?xml') || trimmed.startsWith('<Workbook')) {
      return _parseSpreadsheetML(text);
    }
    return [ImportSheet('CSV', _parseCsv(text))];
  }

  // ---------- Excel 2003 XML (SpreadsheetML) ----------
  static List<ImportSheet> _parseSpreadsheetML(String src) {
    final sheets = <ImportSheet>[];
    final wsRe = RegExp(r'<Worksheet ss:Name="([^"]*)"[\s\S]*?<\/Worksheet>');
    final rowRe = RegExp(r'<Row[^>]*>([\s\S]*?)<\/Row>');
    final cellRe = RegExp(r'<Cell([^>]*)>(?:[\s\S]*?<Data[^>]*>([\s\S]*?)<\/Data>)?[\s\S]*?<\/Cell>');
    final idxRe = RegExp(r'ss:Index="(\d+)"');
    for (final ws in wsRe.allMatches(src)) {
      final name = ws.group(1) ?? '';
      final body = ws.group(0) ?? '';
      final rows = <List<String>>[];
      for (final r in rowRe.allMatches(body)) {
        final cells = <int, String>{};
        var col = 0;
        for (final c in cellRe.allMatches(r.group(1) ?? '')) {
          final idxM = idxRe.firstMatch(c.group(1) ?? '');
          col = idxM != null ? int.parse(idxM.group(1)!) : col;
          var val = (c.group(2) ?? '')
              .replaceAll('&amp;', '&')
              .replaceAll('&lt;', '<')
              .replaceAll('&gt;', '>')
              .replaceAll('&quot;', '"')
              .trim();
          // buang ".0" pada number NIS (mis 2026001.0)
          final asNum = num.tryParse(val);
          if (asNum != null && asNum == asNum.roundToDouble()) {
            val = asNum.toInt().toString();
          }
          cells[col] = val;
          col++;
        }
        if (cells.isEmpty) {
          rows.add(const []);
        } else {
          final maxc = cells.keys.reduce((a, b) => a > b ? a : b);
          rows.add(List.generate(maxc + 1, (i) => cells[i] ?? ''));
        }
      }
      sheets.add(ImportSheet(name, rows));
    }
    return sheets;
  }

  // ---------- DOCX: tabel (baris = baris tabel) + gambar embed PNG ----------
  static List<ImportSheet> _parseDocx(Archive archive) {
    final docFile = archive.firstWhere((f) => f.name == 'word/document.xml');
    final xml = utf8.decode(docFile.readBytes() ?? const <int>[]);
    final rels = <String, String>{};
    for (final f in archive.files) {
      if (f.name == 'word/_rels/document.xml.rels') {
        final rx = utf8.decode(f.readBytes() ?? const <int>[]);
        for (final m in RegExp(r'Id="([^"]+)"[^>]*Target="([^"]+)"').allMatches(rx)) {
          var t = m.group(2)!;
          if (t.startsWith('../')) t = t.substring(3);
          rels[m.group(1)!] = t;
        }
      }
    }
    final images = <String, Uint8List>{};
    for (final f in archive.files) {
      if (f.name.startsWith('word/media/')) {
        images[f.name.substring('word/'.length)] = f.readBytes() ?? Uint8List(0);
      }
    }
    final out = <List<String>>[];
    for (final trm in RegExp(r'<w:tr[^>]*>[\s\S]*?</w:tr>').allMatches(xml)) {
      final tr = trm.group(0)!;
      final cells = <String>[];
      for (final tcm in RegExp(r'<w:tc[^>]*>[\s\S]*?</w:tc>').allMatches(tr)) {
        final tc = tcm.group(0)!;
        final text = RegExp(r'<w:t[^>]*>([^<]*)</w:t>')
            .allMatches(tc)
            .map((m) => _xmlUnescape(m.group(1) ?? ''))
            .join(' ')
            .trim();
        final blips =
            RegExp(r'r:embed="([^"]+)"').allMatches(tc).map((m) => m.group(1)!).toList();
        final imgTokens = <String>[];
        for (final rid in blips) {
          final t = rels[rid];
          if (t != null && images.containsKey(t)) imgTokens.add('«IMG:$t»');
        }
        final merged = (text + (imgTokens.isEmpty ? '' : ' ' + imgTokens.join(' '))).trim();
        if (merged.isNotEmpty) cells.add(merged);
      }
      if (cells.isNotEmpty) out.add(cells);
    }
    if (out.isEmpty) {
      // tanpa tabel: daftar paragraf (satu nama mapel per baris)
      for (final pm in RegExp(r'<w:p[ >][\s\S]*?</w:p>|<w:p/>').allMatches(xml)) {
        final ptxt = RegExp(r'<w:t[^>]*>([^<]*)</w:t>')
            .allMatches(pm.group(0)!)
            .map((m) => _xmlUnescape(m.group(1) ?? ''))
            .join(' ')
            .trim();
        if (ptxt.isNotEmpty) out.add([ptxt]);
      }
    }
    return [ImportSheet('DOCX', out, images)];
  }

  static List<ImportSheet> _parseXlsx(Archive archive) {
    String? shared;
    final sheetFiles = <String>[];
    for (final f in archive) {
      if (f.name == 'xl/sharedStrings.xml') {
        shared = utf8.decode(f.readBytes() ?? Uint8List(0));
      } else if (f.name.startsWith('xl/worksheets/sheet') && f.name.endsWith('.xml')) {
        sheetFiles.add(f.name);
      }
    }
    // nama sheet dari workbook.xml
    final names = <String>[];
    for (final f in archive) {
      if (f.name == 'xl/workbook.xml') {
        final wb = utf8.decode(f.readBytes() ?? Uint8List(0));
        names.addAll(RegExp(r'<sheet [^>]*name="([^"]*)"')
            .allMatches(wb)
            .map((m) => m.group(1) ?? '')
            .toList());
      }
    }
    final strings = <String>[];
    if (shared != null) {
      for (final si in RegExp(r'<si>([\s\S]*?)<\/si>|<si\s*\/>').allMatches(shared)) {
        strings.add(RegExp(r'<t[^>]*>([\s\S]*?)<\/t>')
            .allMatches(si.group(1) ?? '')
            .map((t) => _xmlUnescape(t.group(1) ?? ''))
            .join());
      }
    }
    final sheets = <ImportSheet>[];
    sheetFiles.sort((a, b) => int.parse(RegExp(r'\d+').firstMatch(a)!.group(0)!).compareTo(int.parse(RegExp(r'\d+').firstMatch(b)!.group(0)!)));
    for (var s = 0; s < sheetFiles.length; s++) {
      final file = archive.firstWhere((f) => f.name == sheetFiles[s]);
      final xml = utf8.decode(file.readBytes() ?? Uint8List(0));
      final rows = <List<String>>[];
      for (final rm in RegExp(r'<row[^>]*>([\s\S]*?)<\/row>').allMatches(xml)) {
        final cells = <int, String>{};
        for (final cm in RegExp(r'<c([^>]*)>(?:[\s\S]*?<v>([\s\S]*?)<\/v>)?[\s\S]*?<\/c>|<c([^>]*)\/>').allMatches(rm.group(1) ?? '')) {
          final attrs = cm.group(1) ?? cm.group(3) ?? '';
          var val = cm.group(2) ?? '';
          final ref = RegExp(r'r="([A-Z]+)\d+"').firstMatch(attrs);
          int col;
          if (ref != null) {
            col = _colLetterToIndex(ref.group(1)!);
          } else {
            col = cells.isEmpty ? 0 : cells.keys.reduce((a, b) => a > b ? a : b) + 1;
          }
          if (attrs.contains('t="s"')) {
            final i = int.tryParse(val.trim()) ?? -1;
            val = (i >= 0 && i < strings.length) ? strings[i] : '';
          } else if (attrs.contains('t="inlineStr"')) {
            val = _xmlUnescape(RegExp(r'<t[^>]*>([\s\S]*?)<\/t>').firstMatch(attrs)?.group(1) ?? val);
          } else {
            val = _xmlUnescape(val);
            final n = num.tryParse(val);
            if (n != null && n == n.roundToDouble()) val = n.toInt().toString();
          }
          cells[col] = val.trim();
        }
        final t = RegExp(r'<c[^>]*t="inlineStr"[^>]*>([\s\S]*?)<\/c>').allMatches(rm.group(1) ?? '');
        // fallback: inline strings belum tertangkap pola pertama
        for (final cm in t) {
          final attrs = cm.group(0)!;
          final ref = RegExp(r'r="([A-Z]+)\d+"').firstMatch(attrs);
          if (ref == null) continue;
          final col = _colLetterToIndex(ref.group(1)!);
          if (cells[col]?.isNotEmpty != true) {
            cells[col] = _xmlUnescape(RegExp(r'<t[^>]*>([\s\S]*?)<\/t>').firstMatch(attrs)?.group(1) ?? '').trim();
          }
        }
        if (cells.isEmpty) {
          rows.add(const []);
        } else {
          final maxc = cells.keys.reduce((a, b) => a > b ? a : b);
          rows.add(List.generate(maxc + 1, (i) => cells[i] ?? ''));
        }
      }
      sheets.add(ImportSheet(s < names.length ? names[s] : 'Sheet${s + 1}', rows));
    }
    return sheets;
  }

  static int _colLetterToIndex(String letters) {
    var n = 0;
    for (final cu in letters.toUpperCase().runes) {
      n = n * 26 + (cu - 64);
    }
    return n - 1;
  }

  // ---------- CSV ----------
  static List<List<String>> _parseCsv(String src) {
    final sep = src.split('\n').first.contains(';') ? ';' : ',';
    return LineSplitter.split(src)
        .map((line) => _splitCsvLine(line, sep))
        .toList();
  }

  static List<String> _splitCsvLine(String line, String sep) {
    final out = <String>[];
    final cur = StringBuffer();
    var inQuote = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuote && i + 1 < line.length && line[i + 1] == '"') {
          cur.write('"');
          i++;
        } else {
          inQuote = !inQuote;
        }
      } else if (ch == sep && !inQuote) {
        out.add(cur.toString().trim());
        cur.clear();
      } else {
        cur.write(ch);
      }
    }
    out.add(cur.toString().trim());
    return out;
  }

  static String _xmlUnescape(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll(RegExp(r'_x[0-9A-Fa-f]{4}_'), '')
      .replaceAll('<unknown:Keyword/>', '');
}

/// Normalisasi tabel siswa: temukan header, petakan kolom NIS/NAMA/dsb,
/// dan hasilkan baris siap-RPC. kelas diambil dari nama sheet bila kolom tak ada.
class SiswaTable {
  final String kelas;
  final int? tingkat;
  final List<Map<String, String>> rows;
  SiswaTable(this.kelas, this.tingkat, this.rows);
}

class SiswaImportMapper {
  static final RegExp _headerNoise = RegExp(r'\.|\s|\(|\)', caseSensitive: false);

  static ImportSheet _cleanSheet(ImportSheet s) {
    final name = s.name
        .replaceFirst(RegExp(r'^\s*\d+\.\s*'), '')
        .trim();
    return ImportSheet(name, s.rows);
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(_headerNoise, '').trim();

  static List<SiswaTable> fromSheets(List<ImportSheet> sheets) {
    final out = <SiswaTable>[];
    for (final raw in sheets) {
      final sheet = _cleanSheet(raw);
      final table = _mapSheet(sheet);
      if (table.rows.where((r) => r['nama']!.isNotEmpty).isEmpty) continue;
      out.add(table);
    }
    if (out.isEmpty && sheets.isNotEmpty) {
      // kemungkinan single-sheet generik (nama/NIS ber kolom header)
      out.add(_mapSheet(_cleanSheet(sheets.first)));
    }
    return out;
  }

  /// Deteksi header baris data siswa: cari baris terakhir yang masih
/// header-ish (mengandung URUT/NAMA/NIS) -> mulai dari bawahnya.
  static int _findDataStart(List<List<String>> rows) {
    var last = -1;
    for (var i = 0; i < rows.length && i < 12; i++) {
      for (final cell in rows[i]) {
        final n = _norm(cell);
        if (n == 'urut' || n.startsWith('nama') || n.contains('nis') ||
            n == 'mhsiswa' || n == 'l/p' || n.contains('jeniskelamin')) {
          last = i;
          break;
        }
      }
    }
    return last + 1;
  }

  static bool _looksName(String s) {
    if (s.isEmpty) return false;
    final clean = s.replaceAll(RegExp(r"[.'’\-()0-9\s]"), '');
    if (clean.length < 3) return false;
    if (!RegExp(r'^[A-Za-z]').hasMatch(s.trim())) return false;
    // bukan label header / angka
    final n = _norm(s);
    if (n == 'nama' || n == 'namasiswa' || n.startsWith('daftar') ||
        n.startsWith('smk') || n == 'l/p' || n == 'kkm' || n == 'mata') {
      return false;
    }
    return true;
  }

  static bool _isNumericCell(String s) {
    return RegExp(r'^\d{3,}(\.0+)?$').hasMatch(s.trim());
  }

  static SiswaTable _mapSheet(ImportSheet sheet) {
    final rows = sheet.rows;
    if (rows.isEmpty) return SiswaTable(sheet.name, null, []);
    final width = rows.map((r) => r.length).fold(0, (a, b) => a > b ? a : b);
    final start = _findDataStart(rows);
    final data = rows.skip(start).toList();

    if (data.isEmpty) return SiswaTable(sheet.name, null, []);

    // kolom nama: yang paling banyak "terlihat seperti nama"
    int namaCol = -1, bestNama = 0;
    for (var c = 0; c < width; c++) {
      var cnt = 0;
      for (final r in data) {
        if (c < r.length && _looksName(r[c])) cnt++;
      }
      if (cnt > bestNama) {
        bestNama = cnt;
        namaCol = c;
      }
    }
    if (namaCol < 0 || bestNama < 2) {
      return SiswaTable(sheet.name, null, []);
    }

    // urut: kolom angka paling kiri sebelum namaCol
    int urutCol = -1;
    for (var c = 0; c < namaCol; c++) {
      var cnt = 0;
      for (final r in data) {
        if (c < r.length && RegExp(r'^\d{1,3}\.0+$|^\d{1,3}$').hasMatch(r[c].trim())) cnt++;
      }
      if (cnt > data.length * 0.4) {
        urutCol = c;
        break;
      }
    }

    // nis/nisn: kolom antara urut dan nama yang HANYA dinilai dari baris berisi nama siswa
    final nameRows = data.where((r) => namaCol < r.length && _looksName(r[namaCol])).toList();
    int nisCol = -1;
    int lo = (urutCol >= 0 ? urutCol + 1 : 0);
    if (lo < namaCol) {
      double best = -1;
      for (var c = lo; c < namaCol; c++) {
        var nums = 0, empt = 0;
        for (final r in nameRows) {
          final raw = c < r.length ? r[c].trim() : '';
          if (raw.isEmpty) {
            empt++;
            continue;
          }
          final cleaned = raw.replaceAll(RegExp(r'[/.\s]+$'), '').replaceAll('.', '').trim();
          if (RegExp(r'^\d{3,}').hasMatch(cleaned)) nums++;
        }
        if (nameRows.isEmpty) continue;
        if (nums + empt == nameRows.length && (nums > 0 || empt == nameRows.length)) {
          final score = (nums / nameRows.length);
          if (score > best && score > 0.6) {
            best = score;
            nisCol = c;
          }
        }
      }
    }

    // jk: kolom tepat setelah nama yang isinya L/P dominan
    int jkCol = -1;
    if (namaCol + 1 < width) {
      final c = namaCol + 1;
      var cnt = 0;
      for (final r in data) {
        final v = (c < r.length ? r[c] : '').trim().toUpperCase();
        if (v == 'L' || v == 'P') cnt++;
      }
      if (cnt > data.length * 0.4) jkCol = c;
    }

    final result = <Map<String, String>>[];
    for (final r in data) {
      String at(int c) => (c >= 0 && c < r.length) ? r[c].trim() : '';
      final nama = at(namaCol);
      if (nama.isEmpty || !_looksName(nama)) continue;
      // nilai bisa "0106545695 /" (NISN kosong NIS) / "2026001" / "1234567890 / 2026001"
      var rawNis = at(nisCol);
      var nis = '';
      var nisn = '';
      final parts = rawNis
          .split(RegExp(r'[/|]'))
          .map((p) => (RegExp(r'(\d{3,})').firstMatch(p)?.group(1) ?? '').trim())
          .where((p) => p.isNotEmpty && !RegExp(r'^0+$').hasMatch(p))
          .toList();
      if (parts.isNotEmpty) {
        final first = parts.first;
        if (first.length >= 5 && first.length <= 10) {
          // NISN (10 digit) / NIS pendek
          if (first.length >= 9) {
            nisn = first;
            nis = parts.length > 1 ? parts[1] : first;
          } else {
            nis = first;
            if (parts.length > 1) nisn = parts[1];
          }
        } else {
          nis = first;
        }
      }
      result.add({
        'nis': nis,
        'nisn': nisn,
        'nama': nama,
        'jk': at(jkCol),
        'kelas': '',
      });
    }
    final kelasName = sheet.name;
    return SiswaTable(
      kelasName,
      _tingkatFromKelas(kelasName),
      result,
    );
  }

  static SiswaTable _mapSheetLegacy(ImportSheet sheet) {
    final rows = sheet.rows;
    // cari baris header
    int headIdx = -1;
    Map<String, int> col = {};
    for (var i = 0; i < rows.length && i < 15; i++) {
      final joined = rows[i].map(_norm).toList();
      final hasUrut = joined.any((c) => c == 'urut');
      final hasNis = joined.any((c) => c.contains('nis') || c == 'nisn/nis');
      final hasNama = joined.any((c) => c == 'namasiswa' || c == 'nama' || c == 'namalengkap');
      if (hasNama && (hasUrut || hasNis)) {
        headIdx = i;
        for (var c = 0; c < joined.length; c++) {
          final v = joined[c];
          if (v == 'urut' || v == 'no' || v == 'no.' || v == 'nomor') {
            col.putIfAbsent('urut', () => c);
          } else if (v == 'namasiswa' || v == 'nama' || v == 'namalengkap' || v == 'namasiswa') {
            col['nama'] = c;
          } else if (v == 'nisn/nis' || v == 'nis/nisn' || v == 'nis' || v == 'nisn') {
            col[v == 'nis' ? 'nis' : v == 'nisn' ? 'nisn' : 'nisn_nis'] = c;
          } else if (v == 'l/p' || v == 'jk' || v == 'jeniskelamin') {
            col['jk'] = c;
          } else if (v == 'kelas' || v == 'rombel') {
            col['kelas'] = c;
          } else if (v == 'nis' && !col.containsKey('nis')) {
            col['nis'] = c;
          }
        }
      }
    }
    if (headIdx < 0) {
      // CSV generik: header = baris pertama
      col = {};
      final hdr = rows.isNotEmpty ? rows.first.map(_norm).toList() : <String>[];
      for (var c = 0; c < hdr.length; c++) {
        final v = hdr[c];
        if (v == 'nama' || v == 'namasiswa' || v == 'namalengkap') col['nama'] = c;
        if (v == 'nis') col['nis'] = c;
        if (v == 'nisn/nis' || v == 'nis/nisn') col['nisn_nis'] = c;
        if (v == 'nisn') col['nisn'] = c;
        if (v == 'jk' || v == 'jeniskelamin' || v == 'l/p') col['jk'] = c;
        if (v == 'kelas' || v == 'rombel') col['kelas'] = c;
      }
      headIdx = rows.isNotEmpty && col.isNotEmpty ? 0 : rows.length;
    }
    int nisCol = col['nis'] ?? col['nisn_nis'] ?? -1;
    final namaCol = col['nama'] ?? -1;
    final kelasCol = col['kelas'] ?? -1;
    final jkCol = col['jk'] ?? -1;

    final result = <Map<String, String>>[];
    for (var i = headIdx + 1; i < rows.length; i++) {
      final r = rows[i];
      String at(int c) => (c >= 0 && c < r.length) ? r[c].trim() : '';
      if (namaCol < 0) break;
      var nama = at(namaCol);
      if (nama.isEmpty) continue;
      // lewati subtotal / bukan nama (angka murni / urut doang)
      if (RegExp(r'^\d+[\.\)]?$').hasMatch(nama)) continue;
      var nis = at(nisCol);
      if (nis.isEmpty) nis = at(nisCol == col['nisn'] ? col['nisn_nis']! : col['nisn'] ?? -1);
      result.add({
        'nis': nis,
        'nama': nama,
        'jk': at(jkCol),
        'kelas': kelasCol >= 0 ? at(kelasCol) : '',
      });
    }
    final kelasName = sheet.name; // sheet-name-based (absensi per rombel)
    final firstKelas = result.firstWhere(
      (e) => e['kelas'] != null && e['kelas']!.isNotEmpty,
      orElse: () => {},
    );
    return SiswaTable(
      firstKelas['kelas']?.isNotEmpty == true ? firstKelas['kelas']! : kelasName,
      _tingkatFromKelas(kelasName.isNotEmpty ? kelasName : (firstKelas['kelas'] ?? '')),
      result,
    );
  }

  static int? _tingkatFromKelas(String kelas) {
    final k = kelas.trim().toUpperCase();
    if (k.startsWith('XII')) return 12;
    if (k.startsWith('XI')) return 11;
    if (k.startsWith('X')) return 10;
    final m = RegExp(r'^(\d)').firstMatch(k);
    return m != null ? int.tryParse(m.group(1)!) : null;
  }
}

/// Mapper tabel mata pelajaran.
/// Menerima:
///  - tabel xlsx/csv dengan kolom MATA PELAJARAN | KODE | JURUSAN | KKM
///  - docx: satu mapel per baris tabel (kolom [0]), atau paragraf bebas.
///    Token «IMG:path» pada sel -> jadi field 'img' (untuk upload logo).
class MapelMapper {
  static final RegExp _imgTok = RegExp(r'«IMG:([^»]+)»');

  static final List<RegExp> _skips = [
    RegExp(r'^(daftar|yayasan|smk|nama siswa|jurusan|kode|mata pelajaran|kkm|no\.?|tahun|semester|ket(erangan)?|urut|siswa|jawaban|soal|pilihan)', caseSensitive: false),
    RegExp(r'^[•*\s]*\d+\s*$', caseSensitive: false),
  ];

  static bool _isNoise(String s) {
    final t = s.trim();
    if (t.isEmpty) return true;
    final cleaned = t.replaceAll(RegExp(r'[.\-–—…\s]'), '');
    if (cleaned.length < 3) return true; // 1-2 huruf = status S/I/A dsb
    if (t.length > 80) return true; // paragraf panjang = bukan mapel
    if (RegExp(r'^\[[^\]]*\]$').hasMatch(t)) return true; // [LOGO], [IMG], dll
    if (RegExp(r'^[\d\s./:()-]+$').hasMatch(t)) return true;
    if (cleaned.length <= 4 && RegExp(r'^[A-Z]\.?$').hasMatch(t)) return true;    if (cleaned.length <= 4 && RegExp(r'^[A-Z]\.?$').hasMatch(t)) return true;
    return _skips.any((r) => r.hasMatch(t));
  }

  static List<Map<String, String>> fromRows(List<List<String>> rows,
      {Map<String, Uint8List> images = const {}}) {
    if (rows.isEmpty) return [];
    final head = rows.first
        .map((e) => e.toLowerCase().replaceAll(_imgTok, '').replaceAll(RegExp(r'[^a-z ]'), '').trim())
        .toList();
    int nameOf(String t) =>
        head.indexWhere((e) => e == t || (t == 'mata pelajaran' && (e == 'mata pelajaran' || e.startsWith('mata pelajaran') || e.startsWith('namamapel') || e == 'mapel')));
    final cName = nameOf('mata pelajaran');
    final cKode = head.indexWhere((e) => e == 'kode');
    final cJur = head.indexWhere((e) => e == 'jurusan');
    final cKkm = head.indexWhere((e) => e == 'kkm');
    final out = <Map<String, String>>[];
    if (cName >= 0) {
      for (final r in rows.skip(1)) {
        String at(int c) => c >= 0 && c < r.length ? r[c] : '';
        var nama = at(cName);
        String img = '';
        final im = _imgTok.firstMatch(nama);
        if (im != null) {
          img = im.group(1)!;
          nama = nama.replaceAll(_imgTok, '').trim();
        }
        nama = nama.trim();
        if (nama.isEmpty || _isNoise(nama)) continue;
        out.add({
          'nama': nama,
          if (cKode >= 0) 'kode': at(cKode).trim(),
          if (cJur >= 0) 'jurusan': at(cJur).trim(),
          if (cKkm >= 0) 'kkm': at(cKkm).trim(),
          if (img.isNotEmpty) 'img': img,
        });
      }
    } else {
      // tanpa header dikenali: kolom pertama tiap baris = nama mapel
      for (final r in rows) {
        if (r.isEmpty) continue;
        var nama = r[0];
        String img = '';
        final im = _imgTok.firstMatch(nama);
        if (im != null) {
          img = im.group(1)!;
          nama = nama.replaceAll(_imgTok, '').trim();
        }
        nama = RegExp(r'^\s*\d+[.)]?\s*').hasMatch(nama)
            ? nama.replaceFirst(RegExp(r'^\s*\d+[.)]?\s*'), '').trim()
            : nama.trim();
        if (nama.isEmpty || _isNoise(nama)) continue;
        out.add({'nama': nama, if (img.isNotEmpty) 'img': img});
      }
    }
    return out;
  }
}