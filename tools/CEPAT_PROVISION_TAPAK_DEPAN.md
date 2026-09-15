# Provisioning 50 HP — TANPA PC (pakai 1 HP Android + Termux)

## Konsep
HP-stasiun (punya Termux, boleh apa saja) = "komputer". HP siswa = 49 lainnya.
Semua lewat WiFi. HP siswa TIDAK perlu root. Cukup:
1. Developer options ON (Settings > Tentang > Build number 7x)
2. **Wireless debugging ON** → "Pair device with pairing code" (muncul IP:port + 6 digit)
3. Akun Google/Xiaomi di HP siswa **kosongkan** (syarat device-owner) — setting > akun > hapus semua

## Sekali jalan di HP-stasiun (Termux)
```bash
pkg install -y android-tools
mkdir -p ~/cbt-prov && cp app-release.apk ~/cbt-prov/   # APK v22
bash provision_wifi.sh        # dari folder tools repo / salin isinya
```
## Per HP siswa (pandu satu-satu)
- Siswa buka **Wireless debugging** → **Pair** → baca **IP:port_pairing** + **6 digit** → masukkan ke skrip
- Lalu baca **IP:port utama** di halaman wireless debugging → masukkan
- Skrip otomatis: `adb install app-release.apk` → `dpm set-device-owner` → **TERKUNCI PENUH** ✅
- Indikator sukses: "Success". HP siswa tidak bisa keluar status bar/recents/camera saat ujian.

## Kalau tidak sempat provisioning
Aplikasi tetap jalan mode FALLBACK: lock immersive saat mengerjakan,
back diblokir, keluar app = alarm mp3 + volume otomatis full + bandel (service
hidup lagi walau app di-swipe), balik ke aplikasi = alarm mati.
Nilai & keamanan data sudah diurus server (kunci ga akan bocor).
