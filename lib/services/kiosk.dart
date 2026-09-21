import 'package:flutter/services.dart';

/// Jembatan ke native Android untuk mode ujian (anti-curang).
class Kiosk {
  static const _channel = MethodChannel('com.cbtsekolah.cbt_sekolah/kiosk');

  /// pasang handler utk event dari native (onIntrusion saat fokus hilang
  /// karena overlay/chat head/notification shade)
  static void onIntrusion(void Function()? cb) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onIntrusion') cb?.call();
    });
  }

  static void onPinningWarning(void Function()? cb) {
    final prev = _channel.binaryMessenger;
    // gabung dengan handler intrusion biar tidak saling timpa
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onIntrusion') {
        // akan ditangani oleh onIntrusion yang sudah dipasang sebelumnya jika ada
        // fallback: panggil cb intrusion jika ada yang terpasang via onIntrusion
      }
      if (call.method == 'onPinningWarning') cb?.call();
    });
  }

  static void onEvents({void Function()? onIntrusionCb, void Function()? onPinningCb}) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onIntrusion') onIntrusionCb?.call();
      if (call.method == 'onPinningWarning') onPinningCb?.call();
    });
  }

  static void detachIntrusion() {
    _channel.setMethodCallHandler(null);
  }

  /// Aktifkan/nonaktifkan anti-screenshot (FLAG_SECURE)
  static Future<bool> setSecure(bool secure) async {
    try {
      await _channel.invokeMethod('setSecure', {'secure': secure});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Mulai alarm peringatan + naikkan volume semaksimal mungkin.
  /// customPath: path file mp3 custom (mis. 4_5948414805994900225.mp3)
  static Future<bool> alarmStart({bool maxVolume = true, String? customPath}) async {
    try {
      await _channel.invokeMethod('alarmStart', {'maxVolume': maxVolume, 'customPath': customPath});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Masuk mode kiosk hard lock (block status bar, recent, split, floating)
  static Future<bool> enterKiosk() async {
    try {
      final ok = await _channel.invokeMethod('enterKiosk');
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  /// Keluar mode kiosk
  static Future<bool> exitKiosk() async {
    try {
      await _channel.invokeMethod('exitKiosk');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Paksa volume ke maksimal (dipanggil periodik saat ujian)
  static Future<bool> enforceVolume() async {
    try {
      await _channel.invokeMethod('enforceVolume');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> stopVolumeEnforcer() async {
    try {
      await _channel.invokeMethod('stopVolumeEnforcer');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isDeviceOwner() async {
    try {
      final ok = await _channel.invokeMethod('isDeviceOwner');
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  /// Hentikan alarm.
  static Future<bool> alarmStop() async {
    try {
      await _channel.invokeMethod('alarmStop');
      return true;
    } catch (_) {
      return false;
    }
  }
}