-- CBT 0055: jadwal siswa terdekat mengikuti filter kelas yang sama dengan ujian
-- Filter kelas tetap memakai ujian_izinkan_kelas() (ujian_kelas dari form guru).
-- Perbaikan: timezone Asia/Jakarta, jadwal lewat tidak muncul, urut terdekat dulu.

create or replace function public.jadwal_siswa_aktif()
returns jsonb
language sql
stable
security definer
set search_path = public
set "TimeZone" = 'Asia/Jakarta'
as $$
  with me as (
    select s2.kelas_id
    from public.profiles p
    join public.siswa s2 on s2.nis = p.nis or s2.nisn = p.nis
    where p.id = auth.uid()
    limit 1
  ), picked as (
    select
      u.id,
      u.nama as ujian_nama,
      mp.nama as mapel,
      u.tanggal,
      s.nama as sesi_nama,
      s.jam_mulai,
      s.jam_selesai,
      r.nama as ruang_nama
    from public.ujian u
    cross join me
    left join public.mata_pelajaran mp on mp.id = u.mapel_id
    left join public.atur_ruang_sesi ars
      on ars.ujian_id = u.id and ars.kelas_id = me.kelas_id
    left join public.sesi s on s.id = ars.sesi_id
    left join public.ruang r on r.id = ars.ruang_id
    where u.status = 'aktif'
      and (u.tanggal is null or u.tanggal >= current_date - interval '30 days')
      and me.kelas_id is not null
      and public.ujian_izinkan_kelas(u.id, me.kelas_id)
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'ujian_id', id,
    'ujian_nama', ujian_nama,
    'mapel', mapel,
    'tanggal', tanggal::text,
    'sesi_nama', sesi_nama,
    'jam_mulai', jam_mulai::text,
    'jam_selesai', jam_selesai::text,
    'ruang_nama', ruang_nama
  ) order by tanggal asc nulls last, jam_mulai asc nulls last), '[]'::jsonb)
  from picked;
$$;

create or replace function public.jadwal_siswa_terdekat(p_limit integer default 3)
returns jsonb
language sql
stable
security definer
set search_path = public
set "TimeZone" = 'Asia/Jakarta'
as $$
  with me as (
    select s2.kelas_id
    from public.profiles p
    join public.siswa s2 on s2.nis = p.nis or s2.nisn = p.nis
    where p.id = auth.uid()
    limit 1
  ), picked as (
    select
      u.id,
      u.nama as ujian_nama,
      mp.nama as mapel,
      u.tanggal,
      s.nama as sesi_nama,
      s.jam_mulai,
      s.jam_selesai,
      r.nama as ruang_nama
    from public.ujian u
    cross join me
    left join public.mata_pelajaran mp on mp.id = u.mapel_id
    left join public.atur_ruang_sesi ars
      on ars.ujian_id = u.id and ars.kelas_id = me.kelas_id
    left join public.sesi s on s.id = ars.sesi_id
    left join public.ruang r on r.id = ars.ruang_id
    where u.status = 'aktif'
      and (u.tanggal is null or u.tanggal >= current_date)
      and me.kelas_id is not null
      and public.ujian_izinkan_kelas(u.id, me.kelas_id)
    order by u.tanggal asc nulls last, s.jam_mulai asc nulls last
    limit greatest(1, least(coalesce(p_limit, 3), 10))
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'ujian_id', id,
    'ujian_nama', ujian_nama,
    'mapel', mapel,
    'tanggal', tanggal::text,
    'sesi_nama', sesi_nama,
    'jam_mulai', jam_mulai::text,
    'jam_selesai', jam_selesai::text,
    'ruang_nama', ruang_nama
  ) order by tanggal asc nulls last, jam_mulai asc nulls last), '[]'::jsonb)
  from picked;
$$;

revoke all on function public.jadwal_siswa_terdekat(integer) from public, anon;
grant execute on function public.jadwal_siswa_terdekat(integer) to authenticated;
