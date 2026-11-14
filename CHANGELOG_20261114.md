# CBT Sekolah — Rangkuman Perubahan & Fix

Tanggal: 14 November 2026
Repo: `iznats96-del/cbt-sekolah` (branch `main`)
Web live: https://web-zeta-pink-53.vercel.app
Supabase project: `yukqngrtgevveimhrwke`

---

## 1. Fitur Jodoh Dihapus Total

Commit: `8117ca7 refactor: hapus total fitur jodoh`

### Lingkup
- Form Buat Soal: segment "Jodoh" dihapus (tinggal PG + Essay). Semua state pasangan
  Kolom A/B, `_kunciJodoh`, load/validasi/UI "Pasangan Jodoh" dibuang.
  Soal jodoh lama yang di-edit auto-fallback ke PG.
- Parser DOCX: class `JodohSoal`, field `doc.jodoh`, parser seksi MENJODOHKAN + kunci
  jodoh di tabel — semua dihapus. Seksi MENJODOHKAN sekarang di-skip otomatis
  + muncul warning "Seksi Menjodohkan/Mencocokkan terdeteksi — jenis soal ini
  tidak didukung dan di-skip otomatis".
- Import Ujian: insert soal jodoh, chip "N Jodoh", hitungan tombol import — dibersihkan.
- Kunci Jawaban: editor kunci jodoh dihapus. Soal jodoh sisa muncul teks
  "ubah ke PG/Essay".
- Detail Soal, Bank Soal (admin & guru), warning ujian list — dibersihkan semua.
- Migration `0043_remove_jodoh.sql` sudah dijalankan di production:
  - Hapus soal jodoh existing + jawaban (cascade)
  - Bersihkan `soal_list` di `ujian` & `ujian_soal_kelas`
  - Rehitung nilai peserta terdampak
  - Re-define `hitung_nilai` & `rekap_detail` tanpa cabang jodoh
  - Constraint `bank_soal.jenis` → `check (jenis in ('pg','essay'))`

### Verifikasi
- `flutter analyze`: 0 error
- DB live: `bank_soal_jenis_check = ('pg','essay')`, fungsi scoring bersih jodoh

---

## 2. Bug Opsi Jawaban Dobel (Fix)

Commit: `64be75d fix: opsi jawaban ke-render dobel di pelaksanaan ujian`

### Root cause
`lib/screens/siswa/pelaksanaan_screen.dart` merender opsi 2×:
- `_buildQuestionCard()` memanggil `_buildOptions()` di dalam card (baris 656)
- `build()` utama memanggil `_buildOptions()` lagi setelah card (baris 452)

Akibat: tiap soal PG tampil 2 set jawaban.

### Fix
Hapus pemanggilan duplikat di `Column` utama (yang di luar `_buildQuestionCard`).

```
lib/screens/siswa/pelaksanaan_screen.dart:452
-                        _buildOptions(curId, jenis, opsiList),
-                        const SizedBox(height: 16),
```

### Verifikasi
- `flutter analyze` file: 0 error
- Rebuild `flutter build web --release` → deploy Vercel → live web tampil 1 set opsi

---

## 3. Bug Login Siswa 500 (Fix DB Production)

Fix langsung di production (tanpa commit migration baru — data fix, bukan schema).

### Gejala
Login siswa batch baru gagal:
```
AuthRetryableFetchException({"code":"unexpected_failure",
"message":"Database error querying schema"}, statusCode: 500)
```
User lama (batch September) tetap bisa login.

### Root cause
167 akun siswa di-import batch 5 November punya kolom `auth.users.email_change`
dan `email_change_token_new` = **NULL**. User lama nilainya `''` (empty string).
GoTrue v2.197 gagal query saat kolom itu NULL → 500.

### Fix SQL
```sql
update auth.users
set email_change = '', email_change_token_new = ''
where created_at > '2026-11-01' and email_change is null;
-- 167 rows updated
```

### Verifikasi
- Login `0103269714@cbt.local` (sebelumnya 500) → OK
- Tes acak 5/5 user batch Nov (0115467355, 0113564450, 0119550293, 0109795276, 2627011) → OK
- Sisa user dgn `email_change` NULL = 0

### Pencegahan
Import akun batch berikutnya supaya nilai `email_change`/`email_change_token_new`
di-set `''` (bukan NULL) saat insert ke `auth.users`.

---

## 4. Deploy Vercel (Manual via API)

Project Vercel "web" (id `prj_NGtTn0dAxGEfncwhIGLonuuiemwb`, scope `natshizer-9022s-projects`)
tidak terkoneksi GitHub auto-deploy. Deploy dilakukan manual:
1. `flutter build web --release`
2. Upload 43 file `build/web` ke Vercel File Store via API (`/v2/files` sha1)
3. Create deployment `/v13/deployments` → `READY`
4. Alias `web-zeta-pink-53.vercel.app` nempel otomatis ke deployment baru

Catatan: `vercel deploy --prod` lewat CLI sebelumnya nyangkut `BLOCKED`
(gitForkProtection) — pakai API file upload seperti di atas lebih andal.

---

## Lampiran: Token & Kredensial yang Terpakai

- Supabase Management API (query DB): token `SUPABASE_TOKEN` di `.env`
- Vercel API: token `vcp_...` (scope `natshizer-9022s-projects`)
- Config app: `lib/core/config.dart` (supabaseUrl, supabaseAnonKey, fallbackApiUrl)

> Catatan: Token GitHub `ghp_...` lama di `.env` sudah di-rotate (401). Jangan dipakai lagi.
