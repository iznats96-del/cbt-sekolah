-- ============================================================
-- CBT 0027: SCOPE hasil/peserta utk guru ke ujian yang DIA miliki (bug #7)
--   sebelum: hasil_guru/peserta_guru_all = is_guru() => semua guru bisa
--   baca SEMUA nilai se-sekolah. sekarang: hanya ujian milik guru tsb
--   (admin tetap penuh). Rekap UI aman krn dropdown ujian sudah owner-scope.
-- ============================================================

drop policy if exists "hasil_guru" on public.hasil_ujian;
create policy "hasil_guru" on public.hasil_ujian
  for select to authenticated using (
    public.is_admin() or exists (
      select 1 from public.peserta_ujian p
      join public.ujian u on u.id = p.ujian_id
      where p.id = hasil_ujian.peserta_ujian_id and u.guru_id = auth.uid()
    )
  );

drop policy if exists "peserta_guru_all" on public.peserta_ujian;
create policy "peserta_guru_all" on public.peserta_ujian
  for select to authenticated using (
    public.is_admin() or exists (
      select 1 from public.ujian u
      where u.id = peserta_ujian.ujian_id and u.guru_id = auth.uid()
    )
  );
