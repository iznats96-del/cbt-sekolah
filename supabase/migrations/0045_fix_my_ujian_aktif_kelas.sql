-- 0045: fix filter kelas di my_ujian_aktif + ujian_izinkan_kelas
-- BUG: (1) lookup siswa pakai `siswa.id = auth.uid()` — SALAH, auth.uid() = profiles.id,
--      siswa harus di-lookup via NIS (profiles.nis = siswa.nis).
--      (2) clause bocor `or (p_kelas is null and exists(...))` → siswa tanpa kelas
--      melihat SEMUA ujian.
begin;

-- (1) ujian_izinkan_kelas: hapus clause bocor, ketatkan aturan
create or replace function public.ujian_izinkan_kelas(p_ujian uuid, p_kelas uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    -- tanpa pemetaan kelas di ujian = semua rombel boleh
    not exists (select 1 from public.ujian_kelas where ujian_id = p_ujian)
    -- ujian multi-kelas: hanya kelas yang terdaftar
    or exists (select 1 from public.ujian_kelas where ujian_id = p_ujian and kelas_id = p_kelas)
    -- kompat: fallback ke kelas_id tunggal
    or (select kelas_id from public.ujian where id = p_ujian) = p_kelas;
$$;
grant execute on function public.ujian_izinkan_kelas(uuid, uuid) to authenticated, service_role;

-- (2) my_ujian_aktif: lookup kelas siswa via NIS (bukan id = auth.uid())
create or replace function public.my_ujian_aktif()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', u.id,
    'nama', u.nama,
    'mapel', mp.nama,
    'kelas', coalesce(
       (select string_agg(k2.nama, ', ') from public.ujian_kelas uk
        join public.kelas k2 on k2.id = uk.kelas_id where uk.ujian_id = u.id),
       k.nama),
    'kelas_ids', public.ujian_kelas_ids(u.id),
    'tanggal', u.tanggal,
    'sesi', s.nama,
    'alokasi_menit', u.alokasi_menit,
    'lama_review_menit', coalesce(u.lama_review_menit, 45),
    'jumlah_soal', coalesce(array_length(u.soal_list, 1), 0)
  ) order by u.tanggal desc), '[]'::jsonb)
  from public.ujian u
  left join public.mata_pelajaran mp on mp.id = u.mapel_id
  left join public.kelas k on k.id = u.kelas_id
  left join public.sesi s on s.id = u.sesi_id
  where u.status = 'aktif'
    and public.uin_window_ok(u.id)
    and public.ujian_izinkan_kelas(u.id,
          (select s2.kelas_id
             from public.profiles p
             join public.siswa s2 on s2.nis = p.nis
            where p.id = auth.uid()
            limit 1));
$$;
grant execute on function public.my_ujian_aktif() to authenticated, service_role;

commit;
