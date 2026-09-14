-- ============================================================
-- CBT SEKOLAH - 0010: API AMAN UNTUK SISWA
-- Prinsip: siswa TIDAK PERNAH membaca tabel ujian / bank_soal
-- secara langsung (kunci & token tidak bocor). Semua lewat RPC
-- security-definer yang memfilter kolom sensitif.
-- ============================================================

-- ---------- helper definer (aman dari rekursi RLS) ----------
create or replace function public.my_siswa_id()
returns uuid language sql stable security definer set search_path = public as $$
  select id from public.siswa where profile_id = auth.uid() limit 1;
$$;

-- uji peserta ini milik siswa yang login
create or replace function public.peserta_milik_saya(p_peserta uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.peserta_ujian pu
    join public.siswa s on s.id = pu.siswa_id
    where pu.id = p_peserta and s.profile_id = auth.uid()
  );
$$;

-- ---------- cabut akses tabel ujian & bank_soal untuk siswa ----------
drop policy if exists "ujian_siswa_read" on public.ujian;
drop policy if exists "soal_guru_select_all" on public.bank_soal;
drop policy if exists "siswa_self_read" on public.siswa;

-- siswa tetap boleh baca baris DIRINYA sendiri (tanpa RPC):
create policy "siswa_self_read" on public.siswa
for select using (auth.uid() = profile_id);

-- ---------- RPC 1: daftar ujian aktif utk siswa -----------
create or replace function public.my_ujian_aktif()
returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', u.id,
    'nama', u.nama,
    'mapel', mp.nama,
    'kelas', k.nama,
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
    and (u.kelas_id is null or u.kelas_id = (select kelas_id from public.siswa where profile_id = auth.uid()));
$$;

-- ---------- RPC 2: verifikasi token + register peserta -----
create or replace function public.cek_token_ujian(p_ujian uuid, p_token text)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_peserta uuid; v_status text; v_isi text; v_token text; srow record;
begin
  select s.id, s.kelas_id into srow from public.siswa s where s.profile_id = auth.uid() limit 1;
  if srow.id is null then raise exception 'Akun siswa belum terdaftar'; end if;

  select token, status into v_token, v_status from public.ujian where id = p_ujian;
  if v_status is distinct from 'aktif' then raise exception 'Ujian tidak aktif'; end if;
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

-- ---------- RPC 3: ambil soal BEZ KUNCI utk peserta ----------
create or replace function public.soal_milik_ujian(p_peserta uuid)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare u record; v_status text; out_items jsonb; jwbn jsonb;
begin
  if not public.peserta_milik_saya(p_peserta) then raise exception 'Akses ditolak'; end if;
  select pu.status, u2.soal_list, u2.alokasi_menit, u2.nama, u2.status as u_status
    into u
    from public.peserta_ujian pu join public.ujian u2 on u2.id = pu.ujian_id
   where pu.id = p_peserta;
  if u is null or u.u_status <> 'aktif' then raise exception 'Ujian tidak tersedia'; end if;

  select jsonb_build_object(
    'soal', coalesce(jsonb_agg(jsonb_build_object(
        'id', s.id, 'jenis', s.jenis, 'soal', s.soal,
        'opsi', s.opsi, 'bobot', s.bobot, 'gambar_url', s.gambar_url)
        order by ord.ordinality), '[]'::jsonb),
    'alokasi_menit', u.alokasi_menit,
    'nama', u.nama,
    'ujian_aktif', (u.u_status = 'aktif')
  )
  into out_items
  from unnest(u.soal_list) with ordinality as ord(sid, ordinality)
  join public.bank_soal s on s.id = ord.sid;

  select coalesce(jsonb_object_agg(j.soal_id, jsonb_build_object(
           'jawaban', j.jawaban, 'ragu', j.ragu_ragu)), '{}'::jsonb)
  into jwbn from public.jawaban_siswa j where j.peserta_ujian_id = p_peserta;

  return out_items || jsonb_build_object('jawaban', jwbn);
end;
$$;

-- ---------- RPC 4: simpan jawaban (auto-save) ----------
create or replace function public.simpan_jawaban(
  p_peserta uuid, p_soal uuid, p_jawaban text, p_ragu boolean default false)
returns void
language plpgsql security definer set search_path = public as $$
declare v_status text;
begin
  if not public.peserta_milik_saya(p_peserta) then raise exception 'Akses ditolak'; end if;
  select status into v_status from public.peserta_ujian where id = p_peserta;
  if v_status is distinct from 'mengikuti' then raise exception 'Tidak sedang mengerjakan'; end if;
  insert into public.jawaban_siswa(peserta_ujian_id, soal_id, jawaban, ragu_ragu, status)
  values (p_peserta, p_soal, coalesce(nullif(p_jawaban,''), null), p_ragu,
          case when nullif(p_jawaban,'') is null then 'kosong' else 'dijawab' end)
  on conflict (peserta_ujian_id, soal_id) do update set
    jawaban = excluded.jawaban, ragu_ragu = excluded.ragu_ragu,
    status = excluded.status, updated_at = now();
end;
$$;

-- ---------- RPC 5: kumpulkan (server-side selesai + nilai) ----------
create or replace function public.kumpulkan_ujian(p_peserta uuid)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_status text;
begin
  if not public.peserta_milik_saya(p_peserta) then raise exception 'Akses ditolak'; end if;
  update public.peserta_ujian
     set status = 'selesai', finished_at = now()
   where id = p_peserta and status = 'mengikuti'
  returning status into v_status;
  begin
    perform public.hitung_nilai(p_peserta);
  exception when others then null; end;
  return jsonb_build_object('selesai', coalesce(v_status,'selesai') = 'selesai');
end;
$$;

grant execute on function public.my_ujian_aktif() to authenticated;
grant execute on function public.cek_token_ujian(uuid, text) to authenticated;
grant execute on function public.soal_milik_ujian(uuid) to authenticated;
grant execute on function public.simpan_jawaban(uuid, uuid, text, boolean) to authenticated;
grant execute on function public.kumpulkan_ujian(uuid) to authenticated;