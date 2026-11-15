-- 0046: fix lookup kelas siswa — profiles.nis bisa berisi NIS atau NISN.
-- Join siswa via nis ATAU nisn (dual match) supaya semua akun siswa dapet kelas.
begin;

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
             join public.siswa s2
               on s2.nis = p.nis or s2.nisn = p.nis
            where p.id = auth.uid()
            limit 1));
$$;
grant execute on function public.my_ujian_aktif() to authenticated, service_role;

commit;
