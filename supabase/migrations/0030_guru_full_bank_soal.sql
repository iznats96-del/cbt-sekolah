-- ============================================================
-- CBT 0030: GURU AKSES PENUH bank_soal (lihat/edit/hapus SEMUA soal)
--   Permintaan: guru bertanggung jawab, jadi boleh kelola semua soal
--   (termasuk soal hasil import/admin yang guru_id NULL).
--   Siswa TETAP tidak boleh akses (dijaga oleh: tidak ada policy utk siswa
--   + grant hanya authenticated, dan is_guru()/is_admin() wajib true).
-- ============================================================

-- drop semua policy guru lama yang membatasi guru_id = auth.uid()
drop policy if exists "soal_guru_all" on public.bank_soal;
drop policy if exists "soal_guru_select_all" on public.bank_soal;
drop policy if exists "soal_guru_kunci_update" on public.bank_soal;
drop policy if exists "soal_guru_ujian_select" on public.bank_soal;
drop policy if exists "soal_guru_insert" on public.bank_soal;

-- admin: full
drop policy if exists "soal_admin_all" on public.bank_soal;
create policy "soal_admin_all" on public.bank_soal
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- guru: FULL akses ke SEMUA soal (select/insert/update/delete)
create policy "soal_guru_full" on public.bank_soal
  for all to authenticated
  using (public.is_guru())
  with check (public.is_guru());
