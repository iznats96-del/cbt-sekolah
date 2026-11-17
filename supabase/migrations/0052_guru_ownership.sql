-- CBT 0052: ISOLASI DATA GURU
-- Admin melihat semua soal/ujian. Guru HANYA melihat & mengubah
-- soal/ujian yang guru_id-nya = auth.uid() (punyanya sendiri).
-- Menimpa kebijakan lama "guru full access" (migrasi 0030).

do $$
declare r record;
begin
  for r in
    select policyname, tablename
    from pg_policies
    where schemaname = 'public'
      and tablename in ('bank_soal', 'ujian')
  loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

-- ── bank_soal ────────────────────────────────────────────────
create policy "soal_admin_all" on public.bank_soal
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "soal_guru_own" on public.bank_soal
  for all to authenticated
  using (public.is_guru() and guru_id = auth.uid())
  with check (public.is_guru() and guru_id = auth.uid());

-- ── ujian ────────────────────────────────────────────────────
create policy "ujian_admin_all" on public.ujian
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create policy "ujian_guru_own" on public.ujian
  for all to authenticated
  using (public.is_guru() and guru_id = auth.uid())
  with check (public.is_guru() and guru_id = auth.uid());

-- Siswa tidak membaca tabel ujian langsung (memakai RPC/fallback),
-- jadi sengaja tidak dibuat policy untuk siswa.
