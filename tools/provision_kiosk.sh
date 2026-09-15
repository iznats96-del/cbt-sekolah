#!/usr/bin/env bash
# ============================================================
# PROVISIONING KIOSK CBT — tanpa root, cukup ADB (USB Debugging)
# Colokkan HP ke PC (boleh pakai USB hub utk puluhan HP), jalanin
# skrip ini — semua perangkat yg terdeteksi otomatis diproses parallel.
#
# Prasyarat (di HP):
#   1. Developer Options ON  (Settings > Tentang > ketuk Build number 7x)
#   2. USB Debugging ON
#   3. (MIUI) USB Debugging (Security) ON + cabut akun Xiaomi kalau nyangkut
#   4. Aplikasi CBT Sekolah (app-release.apk) sudah terpasang
#
# Cara pakai:
#   ./provision_kiosk.sh                 # semua perangkat
#   ./provision_kiosk.sh SERIAL1 ...     # atau batasi ke serial tertentu
# ============================================================
set -u
PKG="com.cbtsekolah.cbt_sekolah"
ADMIN="$PKG/.CbtDeviceAdminReceiver"
APK=${APK:-./app-release.apk}

command -v adb >/dev/null || { echo "adb tidak ditemukan — install platform-tools dulu"; exit 1; }
adb start-server >/dev/null 2>&1

DEVICE_LIST=${*:-$(adb devices | awk 'NR>1 && $2=="device"{print $1}')}
[ -z "$DEVICE_LIST" ] && { echo "Tidak ada perangkat terdeteksi (cek kabel/USB debugging)"; exit 1; }

echo "==> Perangkat terdeteksi: $(echo $DEVICE_LIST | wc -w) unit, diproses paralel ..."
for d in $DEVICE_LIST; do
(
  S=$(echo "$d" | sed 's/[ :]/_/g')
  LOG="provision_$S.log"
  {
    echo "[$d] install APK ..."
    [ -f "$APK" ] && adb -s "$d" install -r "$APK" || echo "[$d] skip install (APK tidak ada)"
    # bersihkan device owner lama kalau ada dari percobaan sebelumnya
    adb -s "$d" shell dpm remove-active-admin "$PKG/.CbtDeviceAdminReceiver" >/dev/null 2>&1
    OUT=$(adb -s "$d" shell dpm set-device-owner "$ADMIN" 2>&1)
    if echo "$OUT" | grep -qi "Success"; then
      echo "[$d] ✅ DEVICE OWNER OK — kiosk penuh aktif"
    elif echo "$OUT" | grep -qi "Not allowed to set the global device owner"; then
      echo "[$d] ⚠️ sudah pernah diprovisi (skip)"
    else
      echo "[$d] ❌ GAGAL: $OUT"
      echo "     -> pastikan tidak ada akun tersisa di HP (Settings > Accounts > hapus semua), lalu ulangi"
    fi
  } > "$LOG" 2>&1
  tail -n +1 "$LOG"
) &
done
wait
echo "==> Selesai. Log ada di provision_*.log"
