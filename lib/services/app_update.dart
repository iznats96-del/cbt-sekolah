import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_update_installer_stub.dart'
    if (dart.library.io) 'app_update_installer_mobile.dart';

class UpdateInfo {
  final int build;
  final String label;
  final String apkUrl;
  final String notes;

  const UpdateInfo({
    required this.build,
    required this.label,
    required this.apkUrl,
    required this.notes,
  });
}

class AppUpdate {
  static const _repo = 'iznats96-del/cbt-sekolah';
  static const _autoKey = 'cbt_auto_update';
  static const _latestUrl =
      'https://api.github.com/repos/$_repo/releases/latest';
  static const _fallbackApkUrl =
      'https://github.com/$_repo/releases/latest/download/app-release.apk';

  static Future<int> currentBuild() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return int.tryParse(info.buildNumber) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<String> currentLabel() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version} (${info.buildNumber})';
    } catch (_) {
      return '1.1.3';
    }
  }

  static Future<bool> autoEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoKey) ?? true;
  }

  static Future<void> setAutoEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoKey, value);
  }

  static Future<UpdateInfo?> check() async {
    if (kIsWeb) return null;
    try {
      final response = await http.get(
        Uri.parse(_latestUrl),
        headers: const {
          'User-Agent': 'CBT-Sekolah-Updater',
          'Accept': 'application/vnd.github+json',
        },
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tag = (data['tag_name'] ?? '').toString();
      final latest = int.tryParse(tag.replaceFirst(RegExp(r'^v'), '')) ?? 0;
      final current = await currentBuild();
      if (current == 0 || latest <= current) return null;

      var apkUrl = _fallbackApkUrl;
      final assets = data['assets'] as List?;
      if (assets != null) {
        for (final asset in assets) {
          final a = asset as Map;
          final name = '${a['name'] ?? ''}';
          if (name.toLowerCase().endsWith('.apk')) {
            apkUrl = '${a['browser_download_url']}';
            break;
          }
        }
      }

      return UpdateInfo(
        build: latest,
        label: tag,
        apkUrl: apkUrl,
        notes: (data['body'] ?? '').toString().trim(),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<bool> requestInstallPermission() => ensureInstallPermission();

  static Future<String> download(
    String url,
    void Function(double progress)? onProgress,
  ) =>
      downloadApk(url, onProgress);

  static Future<void> install(String path) => installApk(path);
}
