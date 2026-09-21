-- 0038: perlonggar uin_window_ok — jika tanpa jadwal dan tanpa jam akses, ujian aktif tetap terbuka tanpa cek tanggal
create or replace function public.uin_window_ok(p_ujian uuid)
 returns boolean
 language sql
 stable security definer
 set search_path to 'public'
 set "TimeZone" to 'Asia/Jakarta'
as $function$
  select exists (
    select 1
    from public.ujian u
    left join public.jadwal_mapel j on j.id = u.jadwal_id
    where u.id = p_ujian
      and u.status = 'aktif'
      and (
        -- punya jendela: harus cek tanggal dan jam
        (
          (u.waktu_mulai is not null or u.waktu_selesai is not null or j.id is not null)
          and (u.tanggal is null or u.tanggal = current_date)
          and (
            (u.waktu_mulai is not null and u.waktu_selesai is not null and now() between u.waktu_mulai and u.waktu_selesai)
            or (u.waktu_mulai is not null and u.waktu_selesai is null and now() >= u.waktu_mulai)
            or (u.waktu_mulai is null and u.waktu_selesai is not null and now() <= u.waktu_selesai)
            or (u.waktu_mulai is null and u.waktu_selesai is null and j.id is not null
                and (u.tanggal is null or extract(isodow from u.tanggal)::int = j.hari)
                and now()::time between j.jam_mulai and j.jam_selesai)
          )
        )
        -- tanpa jendela sama sekali: cukup status aktif (kasus "g di isi" tetap kebuka)
        or (u.waktu_mulai is null and u.waktu_selesai is null and j.id is null)
      )
  );
$function$;
