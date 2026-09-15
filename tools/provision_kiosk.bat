@echo off
REM ============================================================
REM PROVISIONING KIOSK CBT untuk Windows — colok HP (USB hub boleh,
REM sampai puluhan paralel), jalankan file ini.
REM Prasyarat HP: Developer Options ON, USB Debugging ON,
REM (MIUI) USB debugging security ON, APK CBT sudah terpasang,
SEMUA akun Google/XIAOMI dihapus dari HP.
REM ============================================================
set PKG=com.cbtsekolah.cbt_sekolah
set ADMIN=%PKG%/.CbtDeviceAdminReceiver
set APK=app-release.apk

where adb >nul 2>nul || (echo adb tidak ditemukan - install platform-tools & exit /b 1)
adb start-server

for /f "skip=1 tokens=1,2" %%a in ('adb devices') do (
  if "%%b"=="device" (
    echo === %%a ===
    if exist %APK% adb -s %%a install -r %APK%
    adb -s %%a shell dpm remove-active-admin %ADMIN% >nul 2>nul
    adb -s %%a shell dpm set-device-owner %ADMIN%
  )
)
echo Selesai — cari "Success" di tiap perangkat. Account HP hrs kosong dulu sebelum provision.
pause
