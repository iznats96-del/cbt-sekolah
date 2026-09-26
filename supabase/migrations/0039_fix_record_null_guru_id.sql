-- ============================================================
-- 0039: FIX gotcha PL/pgSQL "record NULL saat SELECT kolom NULL"
--   Gejala: fungsi ujian_set_kelas/terbitkan_nomor_peserta menolak
--   ujian yang guru_id-nya NULL (contoh: hasil import DOCX yang nama
--   gurunya tidak cocok), dengan error "Ujian tidak ditemukan".
--   Akar: `select kelas_id, guru_id into u` membuat record kosong (NULL)
--   saat SEMUA kolom terpilih ber- nilai NULL, lalu `if u is null`
--   salah menolak padahal baris ujiannya ada.
--   Fix: ganti cek `u is null` dengan `not found` (FOUND).
-- ============================================================

create or replace function public.ujian_set_kelas(p_ujian uuid, p_kelas uuid[])
returns jsonb
language plpgsql security definer set search_path = public as $$
declare u record;
begin
  select guru_id into u from public.ujian where id = p_ujian;
  if not found then raise exception 'Ujian tidak ditemukan'; end if;
  if not (public.is_admin() or (public.is_guru() and u.guru_id = auth.uid())) then
    raise exception 'Hanya admin/guru pemilik ujian';
  end if;
  delete from public.ujian_kelas where ujian_id = p_ujian;
  if p_kelas is not null and array_length(p_kelas, 1) > 0 then
    insert into public.ujian_kelas (ujian_id, kelas_id)
    select p_ujian, unnest(p_kelas)
    on conflict do nothing;
    -- sinkron kelas_id tunggal = pertama (compat)
    update public.ujian set kelas_id = p_kelas[1] where id = p_ujian;
  else
    update public.ujian set kelas_id = null where id = p_ujian;
  end if;
  return jsonb_build_object('kelas', coalesce(p_kelas, '{}'::uuid[]));
end;
$$;
grant execute on function public.ujian_set_kelas(uuid, uuid[]) to authenticated;

create or replace function public.terbitkan_nomor_peserta(p_ujian uuid)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  u record; s record;
  n int := 0; v_contoh text := '';
  v_info jsonb;
  v_kelas uuid[];
begin
  select kelas_id, guru_id into u from public.ujian where id = p_ujian;
  if not found then raise exception 'Ujian tidak ditemukan'; end if;
  if not (public.is_admin() or (public.is_guru() and u.guru_id = auth.uid())) then
    raise exception 'Hanya admin/guru pemilik ujian';
  end if;

  v_kelas := public.ujian_kelas_ids(p_ujian);
  if v_kelas is not null and array_length(v_kelas,1) > 0 then
    for s in select id from public.siswa where kelas_id = any(v_kelas) order by lower(nama) loop
      insert into public.peserta_ujian (ujian_id, siswa_id, status)
      values (p_ujian, s.id, 'belum')
      on conflict (ujian_id, siswa_id) do nothing;
    end loop;
  elsif u.kelas_id is not null then
    for s in select id from public.siswa where kelas_id = u.kelas_id order by lower(nama) loop
      insert into public.peserta_ujian (ujian_id, siswa_id, status)
      values (p_ujian, s.id, 'belum')
      on conflict (ujian_id, siswa_id) do nothing;
    end loop;
  end if;

  v_info := public.isi_nomor_kosong_core();

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