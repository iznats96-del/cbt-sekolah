import 'package:flutter/services.dart';

/// Jembatan ke native Android untuk mode ujian (anti-curang).
class Kiosk {
  static const _channel = MethodChannel('com.cbtsekolah.cbt_sekolah/kiosk');

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
  static Future<bool> alarmStart({bool maxVolume = true}) async {
    try {
      await _channel.invokeMethod('alarmStart', {'maxVolume': maxVolume});
      return true;
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