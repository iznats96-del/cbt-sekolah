-- ============================================================
-- CBT 0034: NOMOR PESERTA FORMAT JURUSAN-SEMESTER-TAHUN-URUT
--   Format: {KODE}-{S}-{YYZZ}-{NN}
--   Contoh: TKJ-1-2627-01, AKL-1-2627-01, TSM-1-2627-01
--     KODE = jurusan.singkatan (upper), fallback parse kelas / UMM
--     S    = 1 Ganjil / 2 Genap (dari tahun_pelajaran aktif)
--     YYZZ = compact tahun aktif: "2026/2027" -> "2627"
--     NN   = urut abjad NAMA per JURUSAN global (min 2 digit: 01..)
--   Scope urut = SELURUH siswa dalam 1 jurusan (lintas rombel),
--   sehingga nomor stabil dipakai lintas ujian semester itu.
-- ============================================================

-- ---------- helper: kode jurusan utk 1 siswa ----------
create or replace function public.jurusan_kode_for_siswa(p_siswa uuid)
returns text
language plpgsql stable security definer set search_path = public as $$
declare v_sing text; v_kelas text; tok text;
begin
  select upper(btrim(j.singkatan)), k.nama
    into v_sing, v_kelas
    from public.siswa s
    left join public.kelas k on k.id = s.kelas_id
    left join public.jurusan j on j.id = k.jurusan_id
   where s.id = p_siswa;
  if v_sing is not null and btrim(v_sing) <> '' then
    return upper(regexp_replace(v_sing, '\s+', '', 'g'));
  end if;
  -- fallback: cari token huruf 2-4 dari nama kelas, skip X/XI/XII
  if v_kelas is not null then
    for tok in
      select upper((x.m)[1]) from regexp_matches(upper(v_kelas), '([A-Z]{2,4})', 'g') as x(m)
    loop
      if tok not in ('X','XI','XII','KELAS','ROMBEL') then
        return tok;
      end if;
    end loop;
  end if;
  return 'UMM';
end;
$$;

-- ---------- helper: compact tahun "2026/2027" -> "2627" ----------
create or replace function public.tahun_compact(p_nama text)
returns text
language plpgsql immutable as $$
declare m4 text[]; m2 text[]; y1 text;
begin
  if p_nama is null or btrim(p_nama) = '' then
    return right(extract(year from now())::text, 2)
         || right((extract(year from now())::int + 1)::text, 2);
  end if;
  -- 4-digit ganda: "2026/2027" / "2026-2027"
  m4 := regexp_match(p_nama, '(\d{4})\D+(\d{4})');
  if m4 is not null then
    return right(m4[1], 2) || right(m4[2], 2);
  end if;
  -- 4-digit tunggal: "2026" -> "2627"
  m4 := regexp_match(p_nama, '(\d{4})');
  if m4 is not null then
    y1 := right(m4[1], 2);
    return y1 || lpad(((y1::int + 1) % 100)::text, 2, '0');
  end if;
  -- 2-digit ganda: "26/27"
  m2 := regexp_match(p_nama, '(\d{2})\D+(\d{2})');
  if m2 is not null then
    return m2[1] || m2[2];
  end if;
  return right(extract(year from now())::text, 2)
       || right((extract(year from now())::int + 1)::text, 2);
end;
$$;

-- ---------- helper: semester digit "Ganjil"->1 "Genap"->2 ----------
create or replace function public.semester_digit(p_sem text)
returns text
language sql immutable as $$
  select case
    when lower(coalesce($1,'')) like '%genap%' then '2'
    when btrim(coalesce($1,'')) = '2' then '2'
    else '1'
  end;
$$;

-- ---------- utama: terbitkan nomor format baru ----------
create or replace function public.terbitkan_nomor_peserta(p_ujian uuid)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  u record;
  v_semester text := '1';
  v_tahun_nama text;
  v_tahun_compact text;
  v_sem_raw text;
  s record;
  n int := 0;
  v_contoh text := '';
begin
  select kelas_id, guru_id into u from public.ujian where id = p_ujian;
  if u is null then raise exception 'Ujian tidak ditemukan'; end if;
  if not (public.is_admin() or (public.is_guru() and u.guru_id = auth.uid())) then
    raise exception 'Hanya admin/guru pemilik ujian';
  end if;

  -- tahun aktif (fallback: terbaru)
  select tp.nama, tp.semester into v_tahun_nama, v_sem_raw
    from public.tahun_pelajaran tp
   where tp.is_active = true
   order by tp.created_at desc limit 1;
  if v_tahun_nama is null then
    select tp.nama, tp.semester into v_tahun_nama, v_sem_raw
      from public.tahun_pelajaran tp
     order by tp.created_at desc limit 1;
  end if;
  v_semester := public.semester_digit(v_sem_raw);
  v_tahun_compact := public.tahun_compact(v_tahun_nama);

  -- daftarkan siswa rombel ujian sbg peserta (tetap)
  if u.kelas_id is not null then
    for s in select id from public.siswa where kelas_id = u.kelas_id order by lower(nama) loop
      insert into public.peserta_ujian (ujian_id, siswa_id, status)
      values (p_ujian, s.id, 'belum')
      on conflict (ujian_id, siswa_id) do nothing;
    end loop;
  end if;

  -- beri nomor global per jurusan: rank seluruh siswa se-jurusan (A-Z),
  -- lalu tempel ke peserta ujian ini (overwrite agar migrasi 001 -> format baru)
  with semua as (
    select sw.id as siswa_id,
           public.jurusan_kode_for_siswa(sw.id) as kode,
           lower(btrim(sw.nama)) as nm,
           sw.nis as nis
      from public.siswa sw
  ),
  ranked as (
    select siswa_id, kode,
           row_number() over (partition by kode order by nm, nis) as rn
      from semua
  )
  update public.peserta_ujian pu
     set nomor_peserta = r.kode || '-' || v_semester || '-' || v_tahun_compact
                         || '-' || lpad(r.rn::text, 2, '0')
    from ranked r
   where pu.ujian_id = p_ujian
     and pu.siswa_id = r.siswa_id;

  select count(*) into n from public.peserta_ujian where ujian_id = p_ujian;
  select pu.nomor_peserta into v_contoh from public.peserta_ujian pu
   where pu.ujian_id = p_ujian order by pu.nomor_peserta limit 1;

  return jsonb_build_object(
    'total', n,
    'tambah', n,
    'semester', v_semester,
    'tahun', v_tahun_compact,
    'contoh', coalesce(v_contoh, ''),
    'format', 'KODE-S-YYZZ-NN (mis TKJ-1-2627-01)'
  );
end;
$$;

grant execute on function public.jurusan_kode_for_siswa(uuid) to authenticated;
grant execute on function public.terbitkan_nomor_peserta(uuid) to authenticated;
