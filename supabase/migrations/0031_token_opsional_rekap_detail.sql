-- ============================================================
-- CBT 0031: HAPUS TOKEN (langsung mengerjakan) + REKAP DETAIL JAWABAN
--   1) cek_token_ujian: kalau ujian TIDAK punya token valid -> langsung masuk
--      (token tetap didukung bila pengawas masih mau pakai)
--   2) my_ujian_aktif: sudah filter kelas; tambah info agar FE bisa sembunyikan
--      ujian kelas/jurusan lain
--   3) rekap_detail(p_ujian): guru lihat jawaban tiap murid (pg/jodoh/esai)
-- ============================================================

-- (1) cek_token_ujian: token opsional
create or replace function public.cek_token_ujian(p_ujian uuid, p_token text)
returns uuid
language plpgsql security definer
set search_path = public
set timezone = 'Asia/Jakarta'
as $$
declare v_peserta uuid; v_status text; v_token text; v_kelas uuid; srow record;
begin
  select s.id, s.kelas_id into srow from public.siswa s where s.profile_id = auth.uid() limit 1;
  if srow.id is null then raise exception 'Akun siswa belum terdaftar'; end if;

  select token, status, kelas_id into v_token, v_status, v_kelas from public.ujian where id = p_ujian;
  if v_status is distinct from 'aktif' then raise exception 'Ujian tidak aktif'; end if;
  if v_kelas is not null and srow.kelas_id is distinct from v_kelas then
    raise exception 'Bukan kelas untuk ujian ini';
  end if;
  if not public.uin_window_ok(p_ujian) then
    raise exception 'Ujian tidak tersedia di luar jadwal (hari/jam yang ditetapkan)';
  end if;
  -- ===== TOKEN OPSIONAL: hanya cek kalau ujian punya token yang "nyata" =====
  -- token dianggap tidak dipakai bila kosong / '-' / 'TANPA' / 'NONE'
  if v_token is not null
     and btrim(v_token) <> ''
     and upper(btrim(v_token)) not in ('-','TANPA','NONE','BEBAS') then
    if upper(btrim(p_token)) <> upper(btrim(v_token)) then
      raise exception 'Salah token';
    end if;
  end if;

  select id, status into v_peserta, v_status from public.peserta_ujian
    where ujian_id = p_ujian and siswa_id = srow.id limit 1;
  if v_peserta is null then
    insert into public.peserta_ujian(ujian_id, siswa_id, status, started_at, token_used)
    values (p_ujian, srow.id, 'mengikuti', now(), coalesce(nullif(btrim(p_token),''),'BEBAS'))
    returning id into v_peserta;
  elsif v_status = 'selesai' then
    raise exception 'Sudah mengerjakan ujian ini';
  else
    update public.peserta_ujian set status='mengikuti', token_used=coalesce(nullif(btrim(p_token),''),'BEBAS') where id = v_peserta;
  end if;
  return v_peserta;
end;
$$;
grant execute on function public.cek_token_ujian(uuid, text) to authenticated, service_role;

-- (2) rekap_detail: guru/admin lihat jawaban tiap murid per soal
create or replace function public.rekap_detail(p_ujian uuid)
returns jsonb
language plpgsql stable security definer
set search_path = public
set timezone = 'Asia/Jakarta'
as $$
declare out jsonb;
begin
  if not (public.is_admin() or public.is_guru()) then raise exception 'Akses ditolak'; end if;
  select coalesce(jsonb_agg(row_obj order by urut), '[]'::jsonb) into out
  from (
    select pu.id as pid, pu.nomor_peserta, pu.status,
      sw.nama as nama, sw.nis as nis,
      jsonb_build_object(
        'peserta_id', pu.id,
        'nama', sw.nama,
        'nis', sw.nis,
        'nomor', pu.nomor_peserta,
        'status', pu.status,
        'nilai', h.nilai,
        'benar', h.jumlah_benar,
        'salah', h.jumlah_salah,
        'kosong', h.jumlah_kosong,
        'detail', coalesce((
           select jsonb_agg(jsonb_build_object(
             'soal_id', s.id,
             'jenis', s.jenis,
             'soal', s.soal,
             'opsi', s.opsi,
             'kunci', case when s.jenis in ('pg','jodoh') then s.kunci->>'jawaban' else null end,
             'jawaban', j.jawaban,
             'nilai_esai', j.nilai,
             'benar', case
                 when s.jenis in ('pg','jodoh')
                   then (nullif(lower(btrim(j.jawaban)),'') is not null
                         and lower(btrim(j.jawaban)) = lower(btrim(s.kunci->>'jawaban')))
                 else null end
           ) order by o.ordn)
           from unnest(u.soal_list) with ordinality as o(sid, ordn)
           join public.bank_soal s on s.id = o.sid
           left join public.jawaban_siswa j on j.peserta_ujian_id = pu.id and j.soal_id = s.id
        ), '[]'::jsonb)
      ) as row_obj,
      row_number() over () as urut
    from public.peserta_ujian pu
    join public.siswa sw on sw.id = pu.siswa_id
    join public.ujian u on u.id = pu.ujian_id
    left join public.hasil_ujian h on h.peserta_ujian_id = pu.id
    where pu.ujian_id = p_ujian
  ) x;
  return out;
end;
$$;
grant execute on function public.rekap_detail(uuid) to authenticated, service_role;
