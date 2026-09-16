-- ============================================================
-- CBT 0026: ANTI-CHEAT WAKTU (bug #1) + hardening privilege (#6)
--  helper peserta_lewat(): pastika jawaban tak bisa disimpan setelah
--  batas waktu = min(started_at + alokasi, akhir jendela/waktu_selesai)
-- ============================================================

-- (0) hardening: revoke EXECUTE from anon/public on all public fns,
--     grant only authenticated + service_role (least privilege)
do $$
declare r record;
begin
  for r in
    select p.oid
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f'
  loop
    execute format('revoke execute on function %s from public, anon', r.oid::regprocedure);
    execute format('grant  execute on function %s to authenticated, service_role', r.oid::regprocedure);
  end loop;
end $$;

-- (1) helper: sisa waktu peserta (bisa negatif = sudah lewat)
create or replace function public.peserta_deadline(p_peserta uuid)
returns timestamptz
language sql stable security definer
set search_path = public
set timezone = 'Asia/Jakarta'
as $$
  select least(
    pu.started_at + (coalesce(u.alokasi_menit, 90) || ' minutes')::interval,
    coalesce(
      u.waktu_selesai,
      case when j.jam_selesai is not null and u.tanggal is not null
           then (u.tanggal + j.jam_selesai) at time zone 'Asia/Jakarta'
           else null end,
      -- tanpa window absolut: hanya alokasi (sangat besar biar tak memotong)
      pu.started_at + interval '9999 years'
    )
  )
  from public.peserta_ujian pu
  join public.ujian u on u.id = pu.ujian_id
  left join public.jadwal_mapel j on j.id = u.jadwal_id
  where pu.id = p_peserta;
$$;

create or replace function public.peserta_lewat(p_peserta uuid, p_grace int default 15)
returns boolean
language sql stable security definer
set search_path = public
set timezone = 'Asia/Jakarta'
as $$
  select case
    when public.peserta_deadline(p_peserta) is null then false
    else now() > public.peserta_deadline(p_peserta) + (coalesce(p_grace,0) || ' seconds')::interval
  end;
$$;

-- (2) simpan_jawaban: TOLAK setelah waktu habis (grace 15 dtk utk submit)
create or replace function public.simpan_jawaban(
  p_peserta uuid, p_soal uuid, p_jawaban text, p_ragu boolean default false)
returns void
language plpgsql security definer set search_path = public as $$
declare v_ujian uuid; v_ok boolean; v_jaw text := nullif(trim(coalesce(p_jawaban,'')), '');
begin
  if v_jaw is not null and length(v_jaw) > 3000 then
    raise exception 'Jawaban terlalu panjang (maks 3000 karakter)';
  end if;
  if not public.peserta_milik_saya(p_peserta) then raise exception 'Akses ditolak'; end if;
  select ujian_id into v_ujian
    from public.peserta_ujian
   where id = p_peserta and status = 'mengikuti';
  if v_ujian is null then raise exception 'Tidak sedang mengerjakan'; end if;
  -- ===== ANTI-CHEAT: waktu habis => kunci jawaban, simpan ditolak =====
  if public.peserta_lewat(p_peserta) then
    raise exception 'Waktu ujian sudah habis — jawaban tidak dapat diubah';
  end if;
  select exists (
    select 1 from public.ujian u
    where u.id = v_ujian and u.soal_list @> array[p_soal]::uuid[]
  ) into v_ok;
  if not v_ok then raise exception 'Soal bukan bagian ujian ini'; end if;
  insert into public.jawaban_siswa(peserta_ujian_id, soal_id, jawaban, ragu_ragu, status)
  values (p_peserta, p_soal, v_jaw, p_ragu,
          case when v_jaw is null then 'kosong' else 'dijawab' end)
  on conflict (peserta_ujian_id, soal_id) do update set
    jawaban = excluded.jawaban, ragu_ragu = excluded.ragu_ragu,
    status = excluded.status, updated_at = now();
end;
$$;

grant execute on function public.simpan_jawaban(uuid, uuid, text, boolean) to authenticated, service_role;
grant execute on function public.peserta_deadline(uuid), public.peserta_lewat(uuid,int) to authenticated, service_role;
