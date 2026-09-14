import 'dart:io';
import '../lib/services/ujian_docx_parser.dart';
void main(){
  final u=UjianDocxParser.parse(File('/data/data/com.termux/files/home/.cache/opencode/tmp/s1.docx').readAsBytesSync());
  for(var i=36;i<u.pg.length && i<41;i++){
    final p=u.pg[i];
    print('[$i] ops=${p.opsi.length} ::[${p.soal}]::');
    print('     opsi=${p.opsi}');
  }
}
