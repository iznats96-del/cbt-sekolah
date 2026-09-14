-- ============================================================
-- CBT SEKOLAH - 0011: HARDENING (kunci & token tak pernah ke siswa)
-- ============================================================

-- peserta select utk siswa pakai definer helper ------------------------------
drop policy if exists "peserta_siswa_self" on public.peserta_ujian;
create policy "peserta_siswa_self" on public.peserta_ujian
for select using (public.peserta_milik_saya(id));

-- (a) hasil utk siswa tanpa akses tabel ujian --------------------------------
create or replace function public.my_hasil()
returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(to_jsonb(x)
             order by x.selesai_pada desc nulls last), '[]'::jsonb)
  from (
    select u.id as ujian_id, u.nama as ujian, mp.nama as mapel, u.tanggal,
           h.jumlah_benar as benar, h.jumlah_salah as salah,
           h.jumlah_kosong as kosong, h.skor, h.nilai,
           coalesce(h.pelanggaran, 0) as pelanggaran,
           h.dinilai, p.status,
           to_char(p.finished_at, 'YYYY-MM-DD HH24:MI') as selesai_pada
    from public.hasil_ujian h
    join public.peserta_ujian p on p.id = h.peserta_ujian_id
    join public.ujian u on u.id = p.ujian_id
    left join public.mata_pelajaran mp on mp.id = u.mapel_id
    join public.siswa s on s.id = p.siswa_id
    where s.profile_id = auth.uid()
  ) x;
$$;
grant execute on function public.my_hasil() to authenticated;

-- (b) log pelanggaran dari client siswa --------------------------------------
create or replace function public.catat_pelanggaran(
  p_peserta uuid, p_jenis text default 'keluar_app')
returns void
language plpgsql security definer set search_path = public as $$
declare v_pel int; v_rinc jsonb;
begin
  if not public.peserta_milik_saya(p_peserta) then return; end if;
  select pelanggaran, coalesce(rincian_pelanggaran, '[]'::jsonb)
    into v_pel, v_rinc
  from public.hasil_ujian where peserta_ujian_id = p_peserta;
  v_rinc := coalesce(v_rinc, '[]'::jsonb) ||
            jsonb_build_array(jsonb_build_object('waktu', now(), 'jenis', p_jenis));
  if v_pel is null then
    insert into public.hasil_ujian (peserta_ujian_id, pelanggaran, rincian_pelanggaran)
    values (p_peserta, 1, v_rinc);
  else
    update public.hasil_ujian
       set pelanggaran = v_pel + 1, rincian_pelanggaran = v_rinc
     where peserta_ujian_id = p_peserta;
  end if;
end;
$$;
grant execute on function public.catat_pelanggaran(uuid, text) to authenticated;

-- (c) hitung_nilai: upsert, riwayat pelanggaran tetap utuh -------------------
create or replace function public.hitung_nilai(p_peserta uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_benar int := 0; v_salah int := 0; v_kosong int := 0;
  v_skor numeric := 0; v_total numeric := 0; v_nilai numeric := 0;
  r record; kj text; jv text;
begin
  for r in
    select s.id as soal_id, s.jenis, s.kunci, s.bobot, j.jawaban
    from public.peserta_ujian pu
    join public.ujian u on u.id = pu.ujian_id
    join public.bank_soal s on s.id = any(u.soal_list)
    left join public.jawaban_siswa j on j.peserta_ujian_id = pu.id and j.soal_id = s.id
    where pu.id = p_peserta
  loop
    v_total := v_total + coalesce(r.bobot, 1);
    jv := nullif(trim(coalesce(r.jawaban, '')), '');

    if r.jenis in ('pg', 'jodoh') then
      kj := r.kunci->>'jawaban';
      if kj is null or kj = '' then
        continue; -- soal tanpa kunci: tak dihitung, guru koreksi manual
      elsif jv is null then
        v_kosong := v_kosong + 1;
      elsif lower(trim(jv)) = lower(trim(kj)) then
        v_benar := v_benar + 1;
        v_skor := v_skor + coalesce(r.bobot, 1);
      else
        v_salah := v_salah + 1;
      end if;
    else
      if jv is null then v_kosong := v_kosong + 1; end if;
    end if;
  end loop;

  if v_total > 0 then v_nilai := round((v_skor / v_total * 100)::numeric, 1); end if;

  insert into public.hasil_ujian
    (peserta_ujian_id, jumlah_benar, jumlah_salah, jumlah_kosong, skor, nilai, dinilai)
  values (p_peserta, v_benar, v_salah, v_kosong, v_skor, v_nilai, true)
  on conflict (peserta_ujian_id) do update set
    jumlah_benar = excluded.jumlah_benar,
    jumlah_salah = excluded.jumlah_salah,
    jumlah_kosong = excluded.jumlah_kosong,
    skor = excluded.skor,
    nilai = excluded.nilai,
    dinilai = true;
  -- pelanggaran TIDAK disentuh
end;
$$;
grant execute on function public.hitung_nilai(uuid) to authenticated;

-- (d) kumpulkan_ujian: selesai + nilai otomatis bila kunci ada ----------------
create or replace function public.kumpulkan_ujian(p_peserta uuid)
returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not public.peserta_milik_saya(p_peserta) then raise exception 'Akses ditolak'; end if;
  update public.peserta_ujian
     set status = 'selesai', finished_at = now()
   where id = p_peserta and status = 'mengikuti';
  begin
    perform public.hitung_nilai(p_peserta);
  exception when others then null; end;
  return jsonb_build_object('selesai', true);
end;
$$;
grant execute on function public.kumpulkan_ujian(uuid) to authenticated;

-- (e) soal utk peserta: TANPA KUNCI + sisa_detik timer -----------------------
create or replace function public.soal_milik_ujian(p_peserta uuid)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare u record; items jsonb; jwbn jsonb; sisa int;
begin
  if not public.peserta_milik_saya(p_peserta) then raise exception 'Akses ditolak'; end if;

  select pu.status as p_status, u2.soal_list, u2.alokasi_menit,
         u2.nama as ujian_nama, u2.status as u_status, pu.started_at
    into u
  from public.peserta_ujian pu
  join public.ujian u2 on u2.id = pu.ujian_id
  where pu.id = p_peserta;

  if u is null or u.u_status <> 'aktif' then
    raise exception 'Ujian tidak tersedia';
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

  return jsonb_build_object(
    'soal', items,
    'jawaban', jwbn,
    'alokasi_menit', u.alokasi_menit,
    'nama', u.ujian_nama,
    'sisa_detik', sisa);
end;
$$;
grant execute on function public.soal_milik_ujian(uuid) to authenticated;