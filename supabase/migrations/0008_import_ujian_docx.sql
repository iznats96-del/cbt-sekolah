-- ============================================================
-- CBT SEKOLAH - 0008: IMPORT UJIAN DOCX (mapel + soal + ujian draft sekali jalan)
-- payload: { mapel, jurusan, kelas, tingkat, judul, waktu, guru, token,
--            jenis_ujian, items:[{jenis pg|jodoh|essay, soal, opsi[], kunci?, gambar_url}] }
-- ============================================================

create or replace function public.admin_import_ujian_docx(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_mapel text; v_jurusan text; v_kelas text; v_tingkat int;
  v_judul text; v_waktu int; v_guru text; v_token text; v_jenis text;
  mapel_id uuid; kelas_id uuid; jenis_id uuid; guru_uid uuid; jid uuid;
  ujian_id uuid; sid uuid;
  soal_ids uuid[] := '{}';
  it jsonb;
begin
  if not (public.is_admin() or public.is_guru()) then
    raise exception 'Hanya admin/guru yang dapat mengimpor ujian';
  end if;

  v_mapel := trim(coalesce(p_payload->>'mapel',''));
  v_jurusan := trim(coalesce(p_payload->>'jurusan',''));
  v_kelas := trim(coalesce(p_payload->>'kelas',''));
  v_tingkat := nullif(coalesce(p_payload->>'tingkat',''),'')::int;
  v_judul := trim(coalesce(p_payload->>'judul','Ujian'));
  v_waktu := coalesce(nullif(coalesce(p_payload->>'waktu',''),'')::int, 60);
  v_guru := trim(coalesce(p_payload->>'guru',''));
  v_jenis := trim(coalesce(nullif(p_payload->>'jenis_ujian',''),'Penilaian Sumatif'));
  v_token := upper(coalesce(nullif(trim(coalesce(p_payload->>'token','')), ''),
                   'T' || substr(replace(md5(random()::text), '-', ''), 1, 5)));

  if v_mapel = '' then
    raise exception 'Mata pelajaran wajib ada';
  end if;

  -- jurusan by nama (auto)
  if v_jurusan <> '' then
    select id into jid from jurusan where lower(trim(nama)) = lower(v_jurusan) limit 1;
    if jid is null then
      insert into jurusan(nama, singkatan) values (v_jurusan, left(v_jurusan, 6))
        on conflict do nothing;
      select id into jid from jurusan where lower(trim(nama)) = lower(v_jurusan) limit 1;
    end if;
  end if;

  -- mapel upsert
  select id into mapel_id from mata_pelajaran where lower(nama) = lower(v_mapel) limit 1;
  if mapel_id is null then
    insert into mata_pelajaran(nama, kkm, jurusan_id) values (v_mapel, 75, jid)
      returning id into mapel_id;
  end if;

  -- kelas upsert (nama 'XI TKJ')
  if v_kelas <> '' then
    select id into kelas_id from kelas where lower(trim(nama)) = lower(v_kelas) limit 1;
    if kelas_id is null then
      insert into kelas(nama, tingkat, jurusan_id)
        values (v_kelas, coalesce(v_tingkat,
          case when upper(v_kelas) like 'XII%' then 12
               when upper(v_kelas) like 'XI%'  then 11
               when upper(v_kelas) like 'X%'   then 10 end), jid)
        on conflict do nothing;
      select id into kelas_id from kelas where lower(trim(nama)) = lower(v_kelas) limit 1;
    end if;
  end if;

  -- jenis ujian
  select id into jenis_id from jenis_ujian where lower(nama) = lower(v_jenis) limit 1;
  if jenis_id is null then
    insert into jenis_ujian(nama) values (v_jenis) on conflict do nothing;
    select id into jenis_id from jenis_ujian where lower(nama) = lower(v_jenis) limit 1;
  end if;

  -- guru by nama (nama = teks guru)
  if v_guru <> '' then
    select p.id into guru_uid from profiles p
      where p.role in ('guru','admin')
        and (lower(p.nama) like '%' || lower(trim(split_part(v_guru, ' dan ', 1))) || '%'
             or lower(coalesce(p.nama,'')) = lower(v_guru))
      limit 1;
  end if;

  -- items soal
  for it in select * from jsonb_array_elements(coalesce(p_payload->'items','[]'::jsonb)) loop
    insert into bank_soal(mapel_id, jenis, soal, opsi, kunci, bobot, gambar_url, pembahasan, guru_id)
    values (
      mapel_id,
      coalesce(nullif(it->>'jenis',''),'pg'),
      it->>'soal',
      case when jsonb_typeof(it->'opsi') = 'array' then it->'opsi' else null end,
      it->'kunci',
      coalesce(nullif(it->>'bobot','')::numeric, 1),
      nullif(coalesce(it->>'gambar_url',''),''),
      nullif(coalesce(it->>'pembahasan',''),''),
      guru_uid
    ) returning id into sid;
    soal_ids := array_append(soal_ids, sid);
  end loop;

  insert into ujian(nama, jenis_ujian_id, mapel_id, kelas_id, guru_id, tanggal,
                    alokasi_menit, token, soal_list, status, catatan)
  values (left(v_judul, 200), jenis_id, mapel_id, kelas_id, guru_uid,
          current_date, v_waktu, v_token, soal_ids, 'draft',
          ('Guru: ' || coalesce(nullif(v_guru,''),'-') || ' • import DOCX'))
  returning id into ujian_id;

  return jsonb_build_object(
    'ujian_id', ujian_id,
    'soal_count', coalesce(array_length(soal_ids,1),0),
    'token', v_token,
    'mapel', v_mapel,
    'kelas', coalesce(v_kelas,'-'),
    'status', 'draft');
end;
$$;

grant execute on function public.admin_import_ujian_docx(jsonb) to authenticated;