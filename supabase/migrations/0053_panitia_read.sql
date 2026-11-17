-- CBT 0053: pulihkan akses baca PANITIA setelah 0052
-- 0052 menghapus semua policy lama, termasuk akses panitia ke ujian.
-- Panitia boleh MEMBACA ujian & bank soal (monitoring, peserta, rekap, cetak).

create or replace function public.is_panitia()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'panitia');
$$;

drop policy if exists "ujian_panitia_read" on public.ujian;
create policy "ujian_panitia_read" on public.ujian
  for select to authenticated
  using (public.is_panitia());

drop policy if exists "soal_panitia_read" on public.bank_soal;
create policy "soal_panitia_read" on public.bank_soal
  for select to authenticated
  using (public.is_panitia());
