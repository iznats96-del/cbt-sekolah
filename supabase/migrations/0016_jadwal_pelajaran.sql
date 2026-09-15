-- ============================================================
-- CBT 0016 — JADWAL PELAJARAN (mapel per hari & jam) sebagai sumber jam ujian
-- ujian.jadwal_id -> jendela akses HARI itu pada TANGGAL ujian, jam mengikuti jadwal
-- 0 = tidak dibatasi ; jam statis waktu_mulai/selesai = override
-- ============================================================

create table if not exists public.jadwal_mapel (
  id uuid primary key default gen_random_uuid(),
  kelas_id uuid not null references public.kelas(id) on delete cascade,
  mapel_id uuid not null references public.mata_pelajaran(id) on delete cascade,
  guru_id uuid references public.profiles(id) on delete set null,
  hari smallint not null check (hari between 1 and 6), -- 1=Senin..6=Sabtu
  jam_mulai time not null,
  jam_selesai time not null,
  keterangan text,
  created_at timestamptz not null default now(),
  unique (kelas_id, hari, jam_mulai)
);

create index if not exists jadwal_kelas_idx on public.jadwal_mapel (kelas_id, hari);

alter table public.jadwal_mapel enable row level security;
create policy jadwal_admin_all on public.jadwal_mapel
  for all using (public.is_admin()) with check (public.is_admin());
create policy jadwal_read on public.jadwal_mapel
  for select using (true);

alter table public.ujian add column if not exists jadwal_id uuid
  references public.jadwal_mapel(id) on delete set null;

-- ===== jendela akses ujian (statis > jadwal-dinamis) ============
create or replace function public.uin_window_ok(p_ujian uuid)
returns boolean
language sql stable security definer
set search_path = public
set timezone = 'Asia/Jakarta'
as $$
  select exists (
    select 1
    from public.ujian u
    left join public.jadwal_mapel j on j.id = u.jadwal_id
    where u.id = p_ujian
      and u.status = 'aktif'
      and (u.tanggal is null or u.tanggal = current_date)
      and case
            when u.waktu_mulai is not null and u.waktu_selesai is not null
              then now() between u.waktu_mulai and u.waktu_selesai
            when u.waktu_mulai is not null
              then now() >= u.waktu_mulai
            when u.waktu_selesai is not null
              then now() <= u.waktu_selesai
            when j.id is not null and u.tanggal is not null
              then (u.tanggal = current_date)
                   and now()::time between j.jam_mulai and j.jam_selesai
            else true
          end
  );
$$;

-- daftar ujian utk siswa: hanya dlm jendela aktifnya
create or replace function public.my_ujian_aktif()
returns jsonb
language sql stable security definer
set search_path = public
set timezone = 'Asia/Jakarta'
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', u.id, 'nama', u.nama, 'mapel', mp.nama, 'kelas', k.nama,
    'tanggal', u.tanggal,
    'jam', case
             when j.id is not null and u.waktu_mulai is null
               then to_char(j.jam_mulai, 'HH24:MI') || ' - ' || to_char(j.jam_selesai, 'HH24:MI')
             when u.waktu_mulai is not null
               then to_char((u.waktu_mulai at time zone 'Asia/Jakarta'), 'HH24:MI') || ' - ' ||
                    to_char((u.waktu_selesai at time zone 'Asia/Jakarta'), 'HH24:MI')
             else null end,
    'alokasi_menit', u.alokasi_menit,
    'jumlah_soal', coalesce(array_length(u.soal_list,1), 0)
  ) order by u.tanggal), '[]'::jsonb)
  from public.ujian u
  left join public.jadwal_mapel j on j.id = u.jadwal_id
  left join public.mata_pelajaran mp on mp.id = u.mapel_id
  left join public.kelas k on k.id = u.kelas_id
  where u.status = 'aktif'
    and (u.tanggal is null or u.tanggal = current_date)
    and public.uin_window_ok(u.id)
    and (u.kelas_id is null or u.kelas_id = (select kelas_id from public.siswa where profile_id = auth.uid()));
$$;

-- token hanya dlm jendela (cek_token sudah pakai uin_window_ok → ikut naik)
-- tapi tambah guard tanggal di cek_token (sebelumnya cek window manual):
create or replace function public.cek_token_ujian(p_ujian uuid, p_token text)
returns uuid
language plpgsql security definer
set search_path = public
set timezone = 'Asia/Jakarta'
as $$
declare v_peserta uuid; v_status text; v_token text; srow record;
begin
  select s.id, s.kelas_id into srow from public.siswa s where s.profile_id = auth.uid() limit 1;
  if srow.id is null then raise exception 'Akun siswa belum terdaftar'; end if;

  select token, status into v_token, v_status from public.ujian where id = p_ujian;
  if v_status is distinct from 'aktif' then raise exception 'Ujian tidak aktif'; end if;
  if not public.uin_window_ok(p_ujian) then
    raise exception 'Ujian tidak tersedia di luar jadwal (hari/jam yang ditetapkan)';
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
    update public.peserta_ujian set status='mengikuti', token_used=p_token where id = v_peserta;
  end if;
  return v_peserta;
end;
$$;

-- soal: window + sisa waktu dibatasi sampai jam_selesai (statis atau jadwal)
create or replace function public.soal_milik_ujian(p_peserta uuid)
returns jsonb
language plpgsql stable security definer
set search_path = public
set timezone = 'Asia/Jakarta'
as $$
declare u record; items jsonb; jwbn jsonb; sisa int; batas timestamptz;
begin
  if not public.peserta_milik_saya(p_peserta) then raise exception 'Akses ditolak'; end if;
  select pu.status as p_status, u2.soal_list, u2.alokasi_menit,
         u2.nama as ujian_nama, u2.status as u_status, pu.started_at,
         u2.waktu_mulai, u2.waktu_selesai, j.jam_mulai, j.jam_selesai,
         u2.tanggal, u2.id as ujian_id
    into u
  from public.peserta_ujian pu
  join public.ujian u2 on u2.id = pu.ujian_id
  left join public.jadwal_mapel j on j.id = u2.jadwal_id
  where pu.id = p_peserta;

  if u is null then raise exception 'Peserta tidak ditemukan'; end if;
  -- yang sudah "mengikuti" boleh resume terus (timer membatasi),
  -- yang belum masuk hanya boleh saat jendela jadwal terbuka
  if u.p_status is distinct from 'mengikuti'
     and not public.uin_window_ok(u.ujian_id) then
    raise exception 'Ujian di luar jadwal hari/jam yang ditetapkan';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
      'id', s.id, 'jenis', s.jenis, 'soal', s.soal,
      'opsi', s.opsi, 'bobot', s.bobot, 'gambar_url', s.gambar_url)
      order by o.ordn), '[]'::jsonb)
    into items
  from unnest(u.soal_list) with ordinality as o(sid, ordn)
  join public.bank_soal s on s.id = o.sid;

  select coalesce(jsonb_object_agg(j2.soal_id, jsonb_build_object(
      'jawaban', j2.jawaban, 'ragu', j2.ragu_ragu)), '{}'::jsonb)
    into jwbn from public.jawaban_siswa j2 where j2.peserta_ujian_id = p_peserta;

  -- sisa = min(alokasi sejak mulai, batas jam) ; batas hard = window end
  sisa := greatest(0, (u.alokasi_menit * 60 -
     coalesce(extract(epoch from (now() - coalesce(u.started_at, now()))), 0))::int);
  if u.waktu_selesai is not null then
    sisa := least(sisa, greatest(0, extract(epoch from (u.waktu_selesai - now()))::int));
  elseif u.jam_selesai is not null and u.tanggal is not null then
    sisa := least(sisa, greatest(0, extract(epoch from (
        (u.tanggal + u.jam_selesai) at time zone 'Asia/Jakarta' - now()))::int));
  end if;

  return jsonb_build_object('soal', items, 'jawaban', jwbn,
    'alokasi_menit', u.alokasi_menit, 'nama', u.ujian_nama, 'sisa_detik', sisa);
end;
$$;

