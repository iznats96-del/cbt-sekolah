#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# TERMUX WIRELESS PROVISIONING — tanpa PC, tanpa root di HP siswa
# Jalankan dari Termux HP "stasiun". Satu per satu HP siswa dipair via
# kode pairing WiFi (Developer Options > Wireless debugging).
# ============================================================
set -u
PKG="com.cbtsekolah.cbt_sekolah"
ADMIN="$PKG/.CbtDeviceAdminReceiver"
APK=${APK:-$HOME/cbt-prov/app-release.apk}

command -v adb >/dev/null 2>&1 || { echo "pkg install -y android-tools dulu"; exit 1; }
adb start-server >/dev/null 2>&1
[ -f "$APK" ] || echo "PERINGATAN: $APK tidak ketemu — lanjut install manual di HP siswa"

N=${1:-0}; i=1; [[ -z "$N" || "$N" == "0" ]] && { read -rp "Jumlah HP siswa yg diproveksi? " N; }
while [ "$i" -le "$N" ]; do
  echo ""
  echo "=== HP ke-$i ==="
  echo "Di HP siswa: Developer options > Wireless debugging > Pair device with pairing code"
  read -rp "  Address pairing (IP:PORT) : " PAIR
  read -rp "  6-digit code              : " CODE
  adb pair "$PAIR" "$CODE" >/tmp/pair.out 2>&1 && echo "  paired ✓" || { echo "  ❌ pair gagal:"; tail -2 /tmp/pair.out; continue; }
  read -rp "  IP:PORT utama (di halaman wireless debugging) : " CONN
  adb connect "$CONN" >/dev/null 2>&1; sleep 1
  if [ -f "$APK" ]; then
    echo "  install APK ..."; adb -s "$CONN" install -r "$APK" >/tmp/ins.out 2>&1 || { echo "  ❌ install gagal"; tail -2 /tmp/ins.out; continue; }
  fi
  adb -s "$CONN" shell dpm remove-active-admin "$ADMIN" >/dev/null 2>&1
  OUT=$(adb -s "$CONN" shell dpm set-device-owner "$ADMIN" 2>&1)
  if echo "$OUT" | grep -qi "Success"; then
    echo "  ✅ DEVICE OWNER — kiosk penuh aktif"
  elif echo "$OUT" | grep -qi "already"; then
    echo "  ✅ sudah device owner (skip)"
  else
    echo "  ❌ $OUT"
    echo "      cek: akun di HP sudah dibersihkan? (Settings>Accounts>hapus semua)"
  fi
  i=$((i+1))
done
echo "Selesai."
