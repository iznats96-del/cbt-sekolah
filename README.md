# CBT Sekolah — SMKN/SMK YP 79 Majalaya

Aplikasi Computer Based Test + Absensi QR (Android APK & Web) — Flutter + Supabase.

## Login
| Peran | Cara masuk |
|---|---|
| Admin | `admin@cbt.sekolah` / `Admin123!` (SEGERA ganti password) |
| Guru | email + password yang dibuatkan admin |
| Siswa | **NIS** di kolom email (otomatis dipetakan `<nis>@cbt.local`) / password awal **`YP` + 4 digit acak** per anak (dibuat saat import) |

Login tahan lonjakan: kalau server menolak (rate-limit 429), aplikasi mengantri ulang otomatis dengan pesan "Server lagi ramai — JANGAN tutup aplikasi".

## Fitur Admin (6 tab: Beranda · Master · Soal · Ujian · Info · Setelan)
- **Data Master**: tahun pelajaran, jurusan, mapel (hapus = cascade bersih via `admin_hapus_mapel`), kelas/rombel (grup per tingkat X/XI/XII + akordeon anggota, pohon per jurusan), guru, siswa (NIS/NISN/JK/ttl/alamat; nomor peserta read-only + tombol salin; ikon 🔑 lihat & reset password), data umum sekolah (nama, NPSN, kepala sekolah, dst).
- **Import Siswa**: file export absensi `.xls` (Excel 2003 XML), `.xlsx`, `.csv` — kolom NIS/NAMA/JK/KELAS auto-deteksi, NIS kosong otomatis dibuat, preview per kelas, password awal seragam/acak.
- **Import Mapel**: `.xlsx`/`.csv`/`.docx` — gambar logo di docx ikut ter-upload ke Storage.
- **Import Ujian dari DOCX**: satu naskah `.docx` sekolah (kop, Mata Pelajaran:, Waktu:, PG `a.–e.`, MENJODOHKAN, Essay, KUNCI JAWABAN `1. B`) → otomatis bikin mapel + bank soal + ujian DRAFT.
- **Jadwal Pelajaran**: CRUD jadwal per rombel (hari, jam mulai–selesai) → bisa dipakai sebagai jendela jam ujian otomatis.
- **Ujian** (menu lengkap per kartu ujian):
  - form: jenis ujian, mapel, **multi-rombel** (satu ujian banyak kelas), sesi, tanggal, **JAM AKSES** `waktu_mulai–waktu_selesai` atau **"Ikuti Jadwal Pelajaran (jam otomatis)"**, alokasi menit, ambil soal dari bank (difilter mapel + cari).
  - **Aktifkan/Akhiri** dengan peringatan bila soal PG belum dikunci; **Kelola Soal** (urungkan/hapus/ambil dari bank).
  - **Kunci Jawaban**: tap opsi benar per PG/jodoh, essay = pedoman; simpan → nilai semua peserta dihitung ulang (`hitung_ujian`).
  - **Koreksi Esai**: nilai manual 0–10 per peserta per soal, preview nilai akhir langsung.
  - **Terbitkan Nomor Peserta**: format `TKJ-1-2627-01` (Jurusan-Semester-TahunAjaran-Urut abjad per jurusan), tersimpan di data siswa.
  - **Cetak Kartu + Nominatif** (PDF via `printing`): kartu peserta 8 per A4 + daftar nominatif bertanda tangan, bisa cari siswa.
  - **Duplikat ke banyak rombel** (jadi DRAFT per kelas), **Hapus ujian** (cascade, bank soal aman).
  - Tanpa token — siswa mulai ujian cukup tap dari daftar (token dihapus total sejak migrasi 0032).
- **Rekap Nilai per Rombel**: rata-rata, % tuntas vs KKM, maks/min, nilai + status + jumlah pelanggaran per anak; tap baris → **detail per soal** (jawaban vs kunci, benar/salah/kosong). Reset per peserta: *ulang*, *buka kembali*, atau *hapus pelanggaran*.
- **Daftar Akun + Password**: semua akun siswa per rombel, salin semua sekaligus (untuk walas), reset massal password.
- **Pengumuman**: CRUD judul/isi, target peran (semua/admin/guru/siswa).

## Fitur Guru (5 tab: Beranda · Soal · Jadwal · Nilai · Absen)
- Bank soal milik sendiri (RLS penuh sejak 0030) + shortcut import DOCX.
- Kelola ujian & nilai sama seperti admin, **terbatas ujian miliknya** (owner-scoped).
- **Scan Absen QR**: kamera (`mobile_scanner`) baca QR di **Kartu Saya** siswa, torch on/off, input NIS manual cadangan, riwayat sesi + anti-duplikat (`catat_hadir` atomic).
- **Presensi manual** (hadir/izin/sakit/alpa se-kelas) + **Rekap Absen** harian (siapa belum masuk), mingguan, bulanan, navigasi tanggal + cari.

## Fitur Siswa (4 tab: Beranda · Hasil · Info · Kartu)
- Beranda: kartu profil, **nomor peserta** (salin), daftar ujian via RPC `my_ujian_aktif` — hanya kelas + jendela jam terbuka; mulai tinggal tap (konfirmasi, tanpa token).
- **Pelaksanaan Ujian**:
  - jawaban **tidak pernah** bocor: soal via RPC `soal_milik_ujian` (kolom kunci disaring server).
  - timer **server-side** (`sisa_detik`) — reload/crash tidak mereset waktu; **autosave offline-toleran** (SharedPreferences + flush batched tiap 2 menit, lanjut setelah mati listrik).
  - tipe PG / Jodoh / Essay + gambar soal, flag "ragu", **palet soal mengambang** (jawaban/ragu/kosong), progress ring, countdown berubah kuning <5 m & merah <1 m, auto-submit saat habis.
  - **Anti-cheat kiosk (native Android)**: FLAG_SECURE (screenshot diblokir saat ujian), immersive sticky, back-button diblokir, deteksi pindah-apply/overlay → **alarm bising + volume dipaksa maksimum + getar**, tercatat `catat_pelanggaran`, **>3× auto-submit**. Mode TERKUNCI penuh (Home/Recents mati) bila HP di-*provision* Device Owner.
- Hasil: nilai per ujian (benar/salah/kosong, skor, pelanggaran). **Kartu Saya**: QR NIS untuk absen + nomor peserta per ujian.

## Keamanan Data
- Semua jalur siswa lewat **RPC SECURITY DEFINER**: `my_ujian_aktif, soal_milik_ujian, simpan_jawaban, kumpulkan_ujian, my_hasil, catat_pelanggaran, catat_hadir, peserta_milik_saya` — tabel `ujian`/`bank_soal` 0 baris untuk siswa; kolom `kunci`/`token` tak pernah keluar.
- RLS penuh per peran; helper `is_admin/is_guru/is_siswa` SECURITY DEFINER (bebas rekursi); hasil guru discoping ke ujian miliknya.
- **Least privilege**: EXECUTE dicabut dari `public`/`anon` di semua fungsi (0026), hanya `authenticated`/`service_role`.
- Validasi input jawaban (≤3000 char, milik sendiri, deadline lock), `kumpulkan_ujian` idempotent, jendela waktu dihitung server dengan TZ `Asia/Jakarta`.
- Anon key publik boleh; `service_role` hanya di script setup.

## Hasil Uji Beban (14 Sep 2026 — Supabase Cloud free)
384 siswa × 65 soal, 12 rombel serentak via API persis alur aplikasi:
- Run 2 (concurrency 8 + backoff): **372/384 full-flow (96.9%)** — 24.180/24.390 jawaban tersimpan, nilai benar, nol error selain login rate-limit.
- Produksi 384 login serentak: pakai **sesi bergelombang** (2–3 sesi jarak 5–10 mnt), atau **Supabase Team**, atau **self-host** (`GOTRUE_RATE_LIMIT_*` dinolkan — paling kuat).

## Build & Deploy
- Push `main` → GitHub Actions: `flutter build apk --release --obfuscate` (signed via Secrets) + web; artifact + Release otomatis `v<run>`.
- Web: `vercel.json` (SPA rewrite) → hosting statis `build/web`.
- Kiosk massal **tanpa PC**: `tools/provision_kiosk_*` (Termux + wireless ADB → `adb install` + `dpm set-device-owner`), lihat `tools/CEPAT_PROVISION_TAPAK_DEPAN.md`.

## Roadmap / Catatan
- Tab **Setelan** admin: backup/restore DB, update aplikasi — masih placeholder.
- Tabel e-learning (`materi`, `tugas`) sudah ada di DB, UI menyusul.

## Perbaikan UI (sesi ini)
- Shell admin/guru: hilangkan app-bar dobel per tab; setiap layar punya app-bar + tombol logout sendiri; konten dibatasi `max-width 860` biar rapi di layar lebar/web.
- Fitur kartu Beranda admin/guru kini benar-benar bisa ditap (sebelumnya `onTap` kosong).
- Error state di semua daftar kini pakai widget `ErrorState` (ikon + pesan + tombol **Muat Ulang**) — tidak lagi text mentah `PostgrestException…`; error jaringan tidak lagi disulap jadi "data kosong" (pengumuman siswa).
- Empty state seragam (`EmptyState`) + tombol CTA berikon, bukan teks `+ Buat ...`.
- Menu ⋮ ujian: item `ListTile dense` → `MenuRow` tinggi 48px (tap-target layak).
- Crash Potential: `substring(0,4)` pada jam jadwal → helper `_hhmm/_jamSingkat` aman; grid statistik rekap tidak lagi memotong baris kedua dropdown.
- Spinner loading di tombol primary kini putih terlihat (login, simpan soal/ujian, dialog CRUD + lebar dialog dibatasi 420px).
- Panel "DIAGNOSTIK" mentah di layar siswa disembunyikan dari build release (`kDebugMode`).
- `withOpacity` (deprecated) dimigrasikan penuh ke `withValues(alpha:)`; `DataTable` pratinjau import dibungkus scroll horizontal (bebas overflow stripe di HP).
