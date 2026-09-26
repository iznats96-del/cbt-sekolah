-- ============================================================
-- 0040: my_ujian_aktif menyaring jendela jam (waktu_mulai/selesai)
--   Sebelumnya daftar ujian siswa hanya menyaring status 'aktif' +
--   kelas. Akibatnya ujian yang belum masuk jendela jam masih tampil
--   (walau tombol mulai tetap ditolak server via uin_window_ok).
--   Fix: pakai uin_window_ok(u.id) yang SAMA persis dengan logika
--   cek_token_ujian -> daftar konsisten dengan yang bisa dikerjakan.
-- ============================================================

create or replace function public.my_ujian_aktif()
returns jsonb
language sql stable security definer set search_path = public as $$
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
    'jumlah_soal', coalesce(array_length(u.soal_list, 1), 0)
  ) order by u.tanggal desc), '[]'::jsonb)
  from public.ujian u
  left join public.mata_pelajaran mp on mp.id = u.mapel_id
  left join public.kelas k on k.id = u.kelas_id
  left join public.sesi s on s.id = u.sesi_id
  where u.status = 'aktif'
    and public.uin_window_ok(u.id)
    and (
      not exists (select 1 from public.ujian_kelas uk where uk.ujian_id = u.id)
      or public.ujian_izinkan_kelas(u.id, (select kelas_id from public.siswa where profile_id = auth.uid()))
    );
$$;
grant execute on function public.my_ujian_aktif() to authenticated, service_role;