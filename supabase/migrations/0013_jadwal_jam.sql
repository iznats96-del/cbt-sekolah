-- ============================================================
-- CBT SEKOLAH - 0013: JADWAL JAM AKTIF + HAPUS UJIAN
--  ujian.waktu_mulai / waktu_selesai (timestamp) = jendela akses siswa
--  RPC uin_window_ok(ujian): cek status aktif + jendela jam
--  my_ujian_aktif & soal_milik_ujian & cek_token dikunci ke jendela
--  RPC admin_hapus_ujian: hapus ujian + jawaban/hasil/peserta (definer)
-- ============================================================

alter table public.ujian
  add column if not exists waktu_mulai timestamptz,
  add column if not exists waktu_selesai timestamptz;

create or replace function public.uin_window_ok(p_ujian uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.ujian u
    where u.id = p_ujian
      and u.status = 'aktif'
      and (u.waktu_mulai   is null or now() >= u.waktu_mulai)
      and (u.waktu_selesai is null or now() <= u.waktu_selesai)
  );
$$;

-- daftar ujian utk siswa: hanya yang jendela jam-nya terbuka
create or replace function public.my_ujian_aktif()
returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', u.id, 'nama', u.nama, 'mapel', mp.nama, 'kelas', k.nama,
    'tanggal', u.tanggal, 'sesi', s.nama, 'alokasi_menit', u.alokasi_menit,
    'jumlah_soal', coalesce(array_length(u.soal_list, 1), 0),
    'waktu_mulai', to_char(u.waktu_mulai, 'DD-MM HH24:MI'),
    'waktu_selesai', to_char(u.waktu_selesai, 'DD-MM HH24:MI')
  ) order by u.waktu_mulai nulls last), '[]'::jsonb)
  from public.ujian u
  left join public.mata_pelajaran mp on mp.id = u.mapel_id
  left join public.kelas k on k.id = u.kelas_id
  left join public.sesi s on s.id = u.sesi_id
  where u.status = 'aktif'
    and (u.waktu_mulai   is null or now() >= u.waktu_mulai)
    and (u.waktu_selesai is null or now() <= u.waktu_selesai)
    and (u.kelas_id is null or u.kelas_id = (select kelas_id from public.siswa where profile_id = auth.uid()));
$$;

-- token hanya sah dlm jendela jam
create or replace function public.cek_token_ujian(p_ujian uuid, p_token text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_peserta uuid; v_status text; v_token text; v_open boolean; srow record;
begin
  select s.id, s.kelas_id into srow from public.siswa s where s.profile_id = auth.uid() limit 1;
  if srow.id is null then raise exception 'Akun siswa belum terdaftar'; end if;

  select token, status into v_token, v_status from public.ujian where id = p_ujian;
  if v_status is distinct from 'aktif' then raise exception 'Ujian tidak aktif'; end if;
  if not public.uin_window_ok(p_ujian) then
    raise exception 'Ujian belum/sudah ditutup sesuai jadwal jam';
  end if;
  if upper(trim(p_token)) <> upper(trim(v_token)) then raise exception 'Salah token'; end if;

  select id, status into v_peserta, v_status from public.peserta_ujian
    where ujian_id = p_ujian and siswa_id = srow.id limit 1;
  if v_peserta is null then
    insert into public.peserta_ujian(ujian_id, siswa_id, status, started_at, token_used)
    values (p_ujian, srow.id, 'mengikuti', now(), p_token)
    returning id into v_peserta;
  elsif v_status = 'selesai' then
    raise exception 'Sudah mengerjakan ujian ini';
  else
    update public.peserta_ujian
       set status = 'mengikuti', token_used = p_token
     where id = v_peserta;
  end if;
  return v_peserta;
end;
$$;

-- akses soal juga dikunci jendela jam (resume harus dlm window)
create or replace function public.soal_milik_ujian(p_peserta uuid)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare u record; items jsonb; jwbn jsonb; sisa int;
begin
  if not public.peserta_milik_saya(p_peserta) then raise exception 'Akses ditolak'; end if;

  select pu.status as p_status, u2.soal_list, u2.alokasi_menit,
         u2.nama as ujian_nama, u2.status as u_status, pu.started_at,
         u2.waktu_mulai, u2.waktu_selesai
    into u
  from public.peserta_ujian pu
  join public.ujian u2 on u2.id = pu.ujian_id
  where pu.id = p_peserta;

  if u is null or u.u_status <> 'aktif' then
    raise exception 'Ujian tidak tersedia';
  end if;
  if (u.waktu_mulai is not null and now() < u.waktu_mulai)
     or (u.waktu_selesai is not null and now() > u.waktu_selesai) then
    raise exception 'Ujian di luar jadwal jam yang ditentukan';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
      'id', s.id, 'jenis', s.jenis, 'soal', s.soal,
      'opsi', s.opsi, 'bobot', s.bobot, 'gambar_url', s.gambar_url)
      order by o.ordn), '[]'::jsonb)
    into items
  from unnest(u.soal_list) with ordinality as o(sid, ordn)
  join public.bank_soal s on s.id = o.sid;

  select coalesce(jsonb_object_agg(j.soal_id, jsonb_build_object(
      'jawaban', j.jawaban, 'ragu', j.ragu_ragu)), '{}'::jsonb)
    into jwbn
  from public.jawaban_siswa j
  where j.peserta_ujian_id = p_peserta;

  sisa := greatest(0, (u.alokasi_menit * 60 -
    coalesce(extract(epoch from (now() - coalesce(u.started_at, now()))), 0))::int);
  -- tetap patuhi waktu_selesai ujian sebagai batas keras
  if u.waktu_selesai is not null then
    sisa := least(sisa, greatest(0, extract(epoch from (u.waktu_selesai - now()))::int));
  end if;

  return jsonb_build_object(
    'soal', items, 'jawaban', jwbn,
    'alokasi_menit', u.alokasi_menit, 'nama', u.ujian_nama,
    'sisa_detik', sisa);
end;
$$;

-- simpan jawaban: boleh selama window atau ≤10 menit setelah selesai (grace)
-- (tidak diubah; hanya kumpulkan yang final) ----------

-- hapus ujian + seluruh turunannya (admin/guru pemilik)
create or replace function public.admin_hapus_ujian(p_ujian uuid)
returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not (public.is_admin() or (public.is_guru() and
        exists(select 1 from public.ujian u where u.id = p_ujian and u.guru_id = auth.uid()))) then
    raise exception 'Tidak diizinkan';
  end if;
  delete from public.jawaban_siswa j
    where j.peserta_ujian_id in (select id from public.peserta_ujian where ujian_id = p_ujian);
  delete from public.hasil_ujian h
    where h.peserta_ujian_id in (select id from public.peserta_ujian where ujian_id = p_ujian);
  delete from public.peserta_ujian where ujian_id = p_ujian;
  delete from public.atur_ruang_sesi where ujian_id = p_ujian;
  delete from public.ujian where id = p_ujian;
  return jsonb_build_object('deleted', true);
end;
$$;
grant execute on function public.admin_hapus_ujian(uuid) to authenticated;