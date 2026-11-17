import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

Future<bool> ensureInstallPermission() async {
  if (!Platform.isAndroid) return true;
  final status = await Permission.requestInstallPackages.status;
  if (status.isGranted) return true;
  final result = await Permission.requestInstallPackages.request();
  if (result.isGranted) return true;
  await openAppSettings();
  return false;
}

Future<String> downloadApk(
  String url,
  void Function(double progress)? onProgress,
) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/cbt-sekolah-update.apk');
  if (await file.exists()) await file.delete();

  final client = http.Client();
  try {
    final request = http.Request('GET', Uri.parse(url));
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('Gagal mengunduh APK (${response.statusCode})');
    }

    final total = response.contentLength;
    var received = 0;
    final sink = file.openWrite();
    try {
      await response.stream.forEach((chunk) {
        sink.add(chunk);
        received += chunk.length;
        if (total != null && total > 0) {
          onProgress?.call((received / total).clamp(0.0, 1.0));
        }
      });
    } finally {
      await sink.close();
    }
  } finally {
    client.close();
  }
  onProgress?.call(1.0);
  return file.path;
}

Future<void> installApk(String path) async {
  final result = await OpenFile.open(path);
  if (result.type != ResultType.done) {
    throw Exception(result.message.isNotEmpty
        ? result.message
        : 'Tidak dapat membuka file APK');
  }
}
