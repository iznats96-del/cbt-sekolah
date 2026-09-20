-- ============================================================
-- CBT 0035: NOMOR PESERTA DI LEVEL SISWA (keluar SAAT IMPORT)
--   - siswa.nomor_peserta: TKJ-1-2627-01 (stabil per anak per tahun)
--   - import -> username (NIS) + password (YPxxxx) + nomor langsung ada
--   - TANPA menunggu tabel ujian; ujian tinggal MENYALIN nomor
--   - nomor lama TIDAK PERNAH diubah (hanya yang kosong yang diisi,
--     lanjut dari max biar kartu yang sudah dicetak tetap valid)
-- ============================================================

alter table public.siswa add column if not exists nomor_peserta text;
create unique index if not exists ux_siswa_nomor
  on public.siswa(nomor_peserta) where nomor_peserta is not null;

-- ---------- inti pengisian (tanpa cek auth; dipanggil internal) ----------
create or replace function public.isi_nomor_kosong_core()
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_nama text; v_semraw text;
  v_sem text; v_th text;
  v_diisi int := 0; v_contoh text := '';
  r record; v_next int;
begin
  perform pg_advisory_xact_lock(20260345); -- serialkan eksekusi ganda
  select tp.nama, tp.semester into v_nama, v_semraw
    from public.tahun_pelajaran tp
   where tp.is_active = true
   order by tp.created_at desc limit 1;
  if v_nama is null then
    select tp.nama, tp.semester into v_nama, v_semraw
      from public.tahun_pelajaran tp
     order by tp.created_at desc limit 1;
  end if;
  v_sem := public.semester_digit(v_semraw);
  v_th := public.tahun_compact(v_nama);

  -- loop per-baris: nomor lama tidak pernah diubah, yang kosong lanjut dari max
  for r in
    select s.id as sid, public.jurusan_kode_for_siswa(s.id) as kode
      from public.siswa s
     where s.nomor_peserta is null
     order by 2, lower(btrim(s.nama)), s.nis
  loop
    select coalesce(max(substring(x.nomor_peserta from '-(\d+)$')::int), 0) + 1
      into v_next
      from public.siswa x
     where x.nomor_peserta ~ ('^' || r.kode || '-' || v_sem || '-' || v_th || '-[0-9]+$');
    update public.siswa
       set nomor_peserta = r.kode || '-' || v_sem || '-' || v_th
                           || '-' || lpad(v_next::text, 2, '0')
     where id = r.sid;
    v_diisi := v_diisi + 1;
  end loop;
  select s.nomor_peserta into v_contoh
    from public.siswa s
   where s.nomor_peserta is not null
   order by s.nomor_peserta limit 1;

  return jsonb_build_object(
    'diisi', v_diisi,
    'contoh', coalesce(v_contoh, ''),
    'semester', v_sem, 'tahun', v_th,
    'format', 'KODE-S-YYZZ-NN (mis TKJ-1-2627-01)'
  );
end;
$$;

-- ---------- RPC admin: isi nomor kosong (dipakai layar Import) ----------
create or replace function public.admin_isi_nomor_kosong()
returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Hanya admin'; end if;
  return public.isi_nomor_kosong_core();
end;
$$;
grant execute on function public.admin_isi_nomor_kosong() to authenticated;

-- ---------- nomor 1 anak (untuk pratinjau) ----------
create or replace function public.nomor_untuk_siswa(p_siswa uuid)
returns text
language plpgsql stable security definer set search_path = public as $$
declare v_kode text; v_sem text; v_th text; v_nama text; v_semraw text; v_rn int;
begin
  select tp.nama, tp.semester into v_nama, v_semraw
    from public.tahun_pelajaran tp
   where tp.is_active = true
   order by tp.created_at desc limit 1;
  v_sem := public.semester_digit(v_semraw);
  v_th := public.tahun_compact(v_nama);
  v_kode := public.jurusan_kode_for_siswa(p_siswa);
  select count(*) + 1 into v_rn
    from public.siswa s
   where public.jurusan_kode_for_siswa(s.id) = v_kode
     and (lower(btrim(s.nama)), s.nis)
         < (select lower(btrim(x.nama)), x.nis from public.siswa x where x.id = p_siswa);
  return v_kode || '-' || v_sem || '-' || v_th || '-' || lpad(v_rn::text, 2, '0');
end;
$$;
grant execute on function public.nomor_untuk_siswa(uuid) to authenticated;

-- ---------- terbitkan per ujian: MENYALIN dari siswa (stabil) ----------
create or replace function public.terbitkan_nomor_peserta(p_ujian uuid)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  u record; s record;
  n int := 0; v_contoh text := '';
  v_info jsonb;
begin
  select kelas_id, guru_id into u from public.ujian where id = p_ujian;
  if u is null then raise exception 'Ujian tidak ditemukan'; end if;
  if not (public.is_admin() or (public.is_guru() and u.guru_id = auth.uid())) then
    raise exception 'Hanya admin/guru pemilik ujian';
  end if;

  -- daftarkan siswa rombel sbg peserta (tetap)
  if u.kelas_id is not null then
    for s in select id from public.siswa where kelas_id = u.kelas_id order by lower(nama) loop
      insert into public.peserta_ujian (ujian_id, siswa_id, status)
      values (p_ujian, s.id, 'belum')
      on conflict (ujian_id, siswa_id) do nothing;
    end loop;
  end if;

  -- pastikan tiap siswa sudah punya nomor (yang kosong saja)
  v_info := public.isi_nomor_kosong_core();

  -- salin nomor siswa -> peserta (overwrite agar seragam)
  update public.peserta_ujian pu
     set nomor_peserta = s.nomor_peserta
    from public.siswa s
   where pu.ujian_id = p_ujian
     and pu.siswa_id = s.id
     and s.nomor_peserta is not null;

  get diagnostics n = row_count;
  select pu.nomor_peserta into v_contoh
    from public.peserta_ujian pu
   where pu.ujian_id = p_ujian
   order by pu.nomor_peserta limit 1;

  return jsonb_build_object(
    'total', (select count(*) from public.peserta_ujian where ujian_id = p_ujian),
    'tambah', n,
    'semester', v_info->>'semester',
    'tahun', v_info->>'tahun',
    'contoh', coalesce(v_contoh, ''),
    'format', 'KODE-S-YYZZ-NN (mis TKJ-1-2627-01, disalin dari data siswa)'
  );
end;
$$;
grant execute on function public.terbitkan_nomor_peserta(uuid) to authenticated;

-- ---------- daftar akun: sertakan nomor peserta ----------
create or replace function public.admin_daftar_akun_siswa()
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare res jsonb;
begin
  if not public.is_admin() then raise exception 'Hanya admin'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'nis', p.nis, 'nama', p.nama, 'pw', p.pw_default,
    'kelas', k.nama, 'nomor', s.nomor_peserta)
    order by k.nama, lower(p.nama)), '[]'::jsonb)
    into res
  from public.profiles p
  left join public.siswa s on s.profile_id = p.id
  left join public.kelas k on k.id = s.kelas_id
  where p.role = 'siswa';
  return res;
end;
$$;
grant execute on function public.admin_daftar_akun_siswa() to authenticated;

-- ---------- backfill: semua siswa lama langsung dapat nomor ----------
select public.isi_nomor_kosong_core();
