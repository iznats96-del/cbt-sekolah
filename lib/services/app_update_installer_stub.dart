Future<bool> hasInstallPermissionPlatform() async => true;

Future<bool> ensureInstallPermission() async => false;

Future<String> downloadApk(
  String url,
  void Function(double progress)? onProgress,
) async =>
    throw UnsupportedError('Pembaruan APK hanya tersedia di Android');

Future<void> installApk(String path) async =>
    throw UnsupportedError('Pembaruan APK hanya tersedia di Android');
