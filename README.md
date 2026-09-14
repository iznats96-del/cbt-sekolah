# CBT Sekolah — SMKN/SMK YP 79 Majalaya

Aplikasi Computer Based Test (Android APK + Web) — Flutter + Supabase.

## Login
| Peran | Cara masuk |
|---|---|
| Admin | `admin@cbt.sekolah` / `Admin123!` (SEGERA ganti password) |
| Guru | email + password yang dibuatkan admin |
| Siswa | **NIS** (kolom email diisi NIS saja) / password **= NIS** (default impor; bisa diganti seragam saat import) |

## Fitur Inti
- **Data Master**: tahun pelajaran, jurusan, mapel, kelas/rombel, guru, siswa + **Import Siswa** (format export absensi `.xls` Excel 2003 XML, `.xlsx`, `.csv` — NIS kosong otomatis dibuat + password = NIS) dan **Import Mapel** (`.docx` juga didukung, gambar ikut jadi logo).
- **Import Ujian dari DOCX** (menu Ujian → ikon upload): satu naskah `.docx` sekolah (kop, Mata Pelajaran:, Kelas:, Waktu:, PILIHAN GANDA `a. A...e. E`, MENJODOHKAN, Essay, KUNCI JAWABAN `1. B`) → otomatis bikin mapel + bank soal + ujian DRAFT (token auto).
- **Editor Kunci Jawaban** per ujian (guru/admin): tap opsi benar per PG/jodoh; essay = pedoman. Setelah simpan → nilai semua peserta dihitung ulang otomatis (RPC `hitung_ujian`).
- **Pelaksanaan Ujian (APK siswa)**:
  - token diverifikasi **di server** (`cek_token_ujian`), bukan client
  - **kunci jawaban tidak pernah dikirim ke siswa** — soal via RPC `soal_milik_ujian` (kolom dinyaring)
  - flag Secure aktif hanya saat ujian (admin/guru bebas screenshot)
  - `resizeableActivity=false` → split-screen diblokir; overlay/floating window terdeteksi saat fokus hilang
  - keluar app → alarm bising + **volume dipaksa maksimum** + getar + tercatat pelanggaran; >3× → auto-submit
  - autosave jawaban per klik; timer server-side (`sisa_detik`) — reload tidak mereset waktu
- Penilaian: PG & Jodoh otomatis dari kunci; Essay manual oleh guru (`penilaian: campuran`).

## Keamanan Data
- Semua akses siswa lewat **RPC security-definer**: `my_ujian_aktif, cek_token_ujian, soal_milik_ujian, simpan_jawaban, kumpulkan_ujian, my_hasil, catat_pelanggaran` — tabel `ujian`/`bank_soal` tidak bisa dibaca siswa (0 row), kolom `kunci`/`token` tidak pernah keluar.
- RLS penuh per peran; kebijakan helper `is_admin/is_guru/is_siswa` = SECURITY DEFINER (bebas rekursi).
- Anon key publik boleh; `service_role` hanya di script setup.

## Hasil Uji Beban (14 Sep 2026 — serverless Supabase Cloud free)
384 siswa × 65 soal, 12 rombel serentak, disimulasikan lewat API persis alur aplikasi:
- Run 1 (concurrency 14): 224 siswa full-flow tanpa error; 160 login kena **rate-limit auth** free tier.
- Run 2 (concurrency 8 + backoff): **372/384 full-flow (96.9%)** — jawaban tersimpan 24.180/24.390, nilai benar, nol error selain login rate-limit; 12 siswa tersisa selesai dengan backoff lebih panjang.
- Auto-koreksi PG dengan kunci: ✅ (benar/salah terhitung; soal tanpa kunci tidak dihitung salah).
- Bocor? ujian read siswa = 0 row, bank_soal = 0 row, rpc soal tanpa field `kunci` ✅.

### Untuk produksi sekolah (384 login serentak)
Pilih salah satu:
1. **Sesi bergelombang** (sudah ada fitur Sesi di menu): 2–3 sesi berjarak 5–10 menit → di bawah 30 login/menit (default limiter free tier).
2. **Supabase Team (USD 25/bln)** → rate limit auth bisa dinaikkan/longgar + support.
3. **Self-host Supabase** di server sekolah → `GOTRUE_RATE_LIMIT_*` bisa nol-kan (paling kuat utk CBT sekolah, data lokal juga).

## Build & Deploy
- Push ke branch `main` → GitHub Actions build `app-release.apk` (signed release/keystore via Secrets) + web.
- Download APK: tab Releases repo ini.
- Kiosk penuh (Home/Recents mati total) = `adb shell dpm set-device-owner` per HP (Device Owner), provisioning sekali per perangkat saat install.
