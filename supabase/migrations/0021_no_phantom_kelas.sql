-- 0021: admin_import_ujian_docx TIDAK lagi auto-bikin kelas/jurusan.
--   kelas: terima kelas_id (dropdown UI); kalau cuma nama → cari FUZZY,
--          tidak ketemu -> kelas_id null (bukan bikin kelas hantu).
--   jurusan mapel: pakai yang ketemu; tidak bikin baru.

create or replace function public.admin_import_ujian_docx(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_mapel text; v_kelas_id uuid; v_kelas text; v_jurusan text;
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
  v_kelas := trim(coalesce(p_payload->>'kelas',''));
  v_jurusan := trim(coalesce(p_payload->>'jurusan',''));
  v_judul := trim(coalesce(p_payload->>'judul','Ujian'));
  v_waktu := coalesce(nullif(coalesce(p_payload->>'waktu',''),'')::int, 60);
  v_guru := trim(coalesce(p_payload->>'guru',''));
  v_jenis := trim(coalesce(nullif(p_payload->>'jenis_ujian',''),'Penilaian Sumatif'));
  v_token := upper(coalesce(nullif(trim(coalesce(p_payload->>'token','')), ''),
                   'T' || substr(replace(md5(random()::text), '-', ''), 1, 5)));
  v_kelas_id := nullif(p_payload->>'kelas_id','')::uuid;

  if v_mapel = '' then raise exception 'Mata pelajaran wajib ada'; end if;

  -- mapel upsert (boleh baru — ini memang data master)
  select id into mapel_id from mata_pelajaran where lower(nama) = lower(v_mapel) limit 1;
  if mapel_id is null then
    -- jurusan hanya dipakai bila SUDAH ada
    jid := null;
    if v_jurusan <> '' then
      select id into jid from jurusan
        where lower(trim(nama)) = lower(v_jurusan) or upper(singkatan) = upper(v_jurusan)
        limit 1;
    end if;
    insert into mata_pelajaran(nama, kkm, jurusan_id) values (v_mapel, 75, jid)
      returning id into mapel_id;
  end if;

  -- kelas: HANYA lookup (dropdown id > fuzzy nama), TIDAK insert
  if v_kelas_id is not null then
    select id into kelas_id from kelas where id = v_kelas_id;
  end if;
  if kelas_id is null and v_kelas <> '' then
    select id into kelas_id from kelas where lower(trim(nama)) = lower(v_kelas) limit 1;
  end if;
  if kelas_id is null and v_kelas <> '' then
    select id into kelas_id from kelas
     where upper(regexp_replace(nama,'\s+',' ','g')) like '%' || split_part(upper(v_kelas),' ',1) || '%'
       and nama ilike '%' || coalesce(nullif(split_part(upper(v_kelas),' ',2),''),'') || '%'
     limit 1;
  end if;

  select id into jenis_id from jenis_ujian where lower(nama) = lower(v_jenis) limit 1;
  if jenis_id is null then
    insert into jenis_ujian(nama) values (v_jenis) on conflict do nothing;
    select id into jenis_id from jenis_ujian where lower(nama) = lower(v_jenis) limit 1;
  end if;

  if v_guru <> '' then
    select p.id into guru_uid from profiles p
      where p.role in ('guru','admin')
        and (lower(p.nama) like '%' || lower(trim(split_part(v_guru, ' dan ', 1))) || '%'
             or lower(coalesce(p.nama,'')) = lower(v_guru))
      limit 1;
  end if;

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
          ('Guru: ' || coalesce(nullif(v_guru,''),'-') || ' • import DOCX' ||
           case when kelas_id is null
             then ' | KELAS BLUM TERPILIH — pilih di dropdown saat edit' else '' end))
  returning id into ujian_id;

  return jsonb_build_object(
    'ujian_id', ujian_id,
    'soal_count', coalesce(array_length(soal_ids,1),0),
    'token', v_token,
    'mapel', v_mapel,
    'kelas', coalesce((select nama from kelas where id = kelas_id), '(belum dipilih)'),
    'status', 'draft');
end;
$$;
grant execute on function public.admin_import_ujian_docx(jsonb) to authenticated;
