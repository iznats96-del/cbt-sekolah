import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart' as xml;

/// Patch template XLSX ASTS tanpa library excel: seluruh ZIP, style, logo,
/// rumus, dan sheet lain dipertahankan — cuma XML sheet yang diubah.
class XlsxPatch {
  XlsxPatch._();

  static List<String> sheetNames(Uint8List templateBytes) {
    final arc = ZipDecoder().decodeBytes(templateBytes);
    final doc = _doc(arc, 'xl/workbook.xml');
    if (doc == null) return const [];
    return doc.findAllElements('sheet').map((e) => e.getAttribute('name') ?? '').where((e) => e.isNotEmpty).toList();
  }

  static Uint8List build({
    required Uint8List templateBytes,
    required String sheetName,
    required String mapel,
    required Map<String, num> nilaiByNama,
  }) {
    final arc = ZipDecoder().decodeBytes(templateBytes);

    final shared = <String>[];
    final ss = _doc(arc, 'xl/sharedStrings.xml');
    if (ss != null) {
      for (final si in ss.findAllElements('si')) {
        shared.add(si.findAllElements('t').map((e) => e.innerText).join());
      }
    }

    final rels = _doc(arc, 'xl/_rels/workbook.xml.rels');
    final ridTarget = <String, String>{};
    if (rels != null) {
      for (final r in rels.findAllElements('Relationship')) {
        final id = r.getAttribute('Id');
        final t = r.getAttribute('Target');
        if (id != null && t != null) ridTarget[id] = t;
      }
    }
    String? target;
    final wb = _doc(arc, 'xl/workbook.xml');
    if (wb != null) {
      for (final s in wb.findAllElements('sheet')) {
        if (s.getAttribute('name') != sheetName) continue;
        final rid = s.attributes
            .firstWhere((a) => a.localName == 'id', orElse: () => s.attributes.first)
            .value;
        target = ridTarget[rid];
        break;
      }
    }
    if (target == null) throw Exception('Sheet "$sheetName" tidak ada di template');
    final sheetPath = target.startsWith('xl/') ? target : 'xl/$target';
    final sheetFile = arc.findFile(sheetPath);
    if (sheetFile == null) throw Exception('File sheet tidak ditemukan: $sheetPath');

    final doc = xml.XmlDocument.parse(String.fromCharCodes(sheetFile.content as Uint8List));
    xml.XmlName nm(String local) => xml.XmlName(local);

    final upper = <String, num>{};
    nilaiByNama.forEach((k, v) => upper[k.trim().toUpperCase()] = v);

    for (final row in doc.findAllElements('row')) {
      final rNum = int.tryParse(row.getAttribute('r') ?? '') ?? 0;
      final cells = <String, xml.XmlElement>{
        for (final c in row.findElements('c')) c.getAttribute('r') ?? '': c,
      };

      if (rNum == 13) {
        _setInline(cells['E13'], mapel, nm);
        _setInline(cells['O13'], sheetName, nm);
        continue;
      }
      if (rNum < 18) continue;

      final nameCell = cells['C$rNum'];
      if (nameCell == null) continue;
      final name = _cellText(nameCell, shared).trim().toUpperCase();
      if (name.isEmpty) continue;
      final nilai = upper[name];
      if (nilai == null) continue;

      final nCell = cells['N$rNum'];
      if (nCell == null) continue;
      nCell.attributes.removeWhere((a) => a.localName == 't');
      final teks = nilai % 1 == 0
          ? nilai.toInt().toString()
          : nilai.toStringAsFixed(1);
      final v = nCell.findElements('v').firstOrNull;
      if (v != null) {
        v.children.clear();
        v.children.add(xml.XmlText(teks));
      } else {
        nCell.children.add(xml.XmlElement(nm('v'), [], [xml.XmlText(teks)]));
      }
    }

    final baru = Uint8List.fromList(doc.toXmlString().codeUnits);
    final hasil = Archive();
    for (final f in arc.files) {
      hasil.addFile(identical(f, sheetFile)
          ? ArchiveFile(f.name, baru.length, baru)
          : f);
    }
    final encoded = ZipEncoder().encode(hasil);
    if (encoded == null) throw Exception('Gagal membuat file XLSX');
    return Uint8List.fromList(encoded);
  }

  static xml.XmlDocument? _doc(Archive arc, String path) {
    final f = arc.findFile(path);
    if (f == null) return null;
    return xml.XmlDocument.parse(String.fromCharCodes(f.content as Uint8List));
  }

  static String _cellText(xml.XmlElement c, List<String> shared) {
    final v = c.findElements('v').firstOrNull?.innerText ?? '';
    final t = c.getAttribute('t');
    if (t == 's') {
      final i = int.tryParse(v) ?? -1;
      return i >= 0 && i < shared.length ? shared[i] : '';
    }
    if (t == 'inlineStr') {
      return c.findElements('is').expand((e) => e.findAllElements('t')).map((e) => e.innerText).join();
    }
    return v;
  }

  static void _setInline(xml.XmlElement? c, String value, xml.XmlName Function(String) nm) {
    if (c == null) return;
    c.attributes.removeWhere((a) => a.localName == 't');
    c.attributes.add(xml.XmlAttribute(nm('t'), 'inlineStr'));
    c.children.clear();
    c.children.add(xml.XmlElement(nm('is'), [], [
      xml.XmlElement(nm('t'), [], [xml.XmlText(value)]),
    ]));
  }
}
