-- ============================================================
-- CBT SEKOLAH - 0007
-- 1) admin_import_siswa: NIS kosong -> AUTO-BUAT 'Nxxxxx' tanpa syarat
--    password = custom bila diisi, selain itu = NIS hasil generate
-- 2) admin_import_mapel: support logo_url (gambar png dari docx)
-- ============================================================

create or replace function public.admin_import_siswa(p_rows jsonb, p_password text default null)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, auth
as $$
declare
  r jsonb;
  v_nis text; v_nama text; v_email text; v_pass text; v_nis2 text;
  v_uid uuid; v_kelas uuid; v_exist uuid;
  v_created int := 0; v_updated int := 0; v_skipped int := 0;
  errors jsonb := '[]'::jsonb;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat mengimpor siswa';
  end if;

  for r in select * from jsonb_array_elements(p_rows) loop
    v_nis := trim(coalesce(r->>'nis',''));
    v_nama := trim(coalesce(r->>'nama',''));
    if v_nama = '' then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    begin
      -- kelas by nama (opsional, auto-create)
      v_kelas := null;
      if coalesce(r->>'kelas','') <> '' then
        select id into v_kelas from kelas where lower(trim(nama)) = lower(trim(r->>'kelas')) limit 1;
        if not found then
          insert into kelas(nama, tingkat)
          values (trim(r->>'kelas'), nullif(r->>'tingkat','')::int)
          on conflict do nothing;
          select id into v_kelas from kelas where lower(trim(nama)) = lower(trim(r->>'kelas')) limit 1;
        end if;
      end if;

      -- cari akun by NIS
      v_exist := null;
      if v_nis <> '' then
        select profile_id into v_exist from siswa where nis = v_nis;
        if v_exist is null then
          select id into v_exist from profiles where nis = v_nis;
        end if;
      end if;

      -- NIS kosong: cocokkan by nama+kelas
      if v_exist is null and v_nis = '' then
        select s.profile_id, s.nis into v_exist, v_nis2
          from siswa s
         where lower(trim(s.nama)) = lower(trim(v_nama))
           and (v_kelas is null or s.kelas_id = v_kelas)
         limit 1;
        if v_exist is not null then
          v_nis := coalesce(v_nis2, '');
        end if;
      end if;

      -- tetap kosong -> auto-generate, TANPA syarat password
      if v_exist is null and v_nis = '' then
        v_nis := 'N' || lpad(nextval('public.nis_seq')::text, 5, '0');
      end if;

      v_email := lower(replace(v_nis,' ','')) || '@cbt.local';
      v_pass := coalesce(nullif(p_password,''), v_nis);

      if v_exist is null then
        v_uid := extensions.gen_random_uuid();
        insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                                email_confirmed_at, created_at, updated_at, last_sign_in_at,
                                confirmation_token, email_change, email_change_token_new,
                                phone_change, phone_change_token, recovery_token,
                                reauthentication_token,
                                is_anonymous, is_sso_user,
                                raw_app_meta_data, raw_user_meta_data)
        values (v_uid, '00000000-0000-0000-0000-000000000000',
                'authenticated', 'authenticated', v_email,
                extensions.crypt(v_pass, extensions.gen_salt('bf')),
                now(), now(), now(), now(),
                '', '', '', '', '', '', '',
                false, false,
                '{"provider":"email","providers":["email"]}'::jsonb,
                jsonb_build_object('role','siswa','nama', v_nama));

        insert into auth.identities (id, user_id, provider_id, provider,
                                     identity_data, last_sign_in_at,
                                     created_at, updated_at)
        values (extensions.gen_random_uuid(), v_uid, v_uid::text, 'email',
                jsonb_build_object('sub', v_uid::text, 'email', v_email, 'email_verified', true),
                now(), now(), now());

        insert into profiles(id, role, nama, nis, email_show)
        values (v_uid, 'siswa', v_nama, v_nis, v_email);

        insert into siswa (nis, nisn, nama, profile_id, kelas_id, jenis_kelamin,
                           tempat_lahir, tanggal_lahir, alamat, no_hp)
        values (v_nis,
                nullif(trim(coalesce(r->>'nisn','')),''),
                v_nama, v_uid, v_kelas,
                nullif(trim(coalesce(r->>'jk','')),''),
                nullif(trim(coalesce(r->>'tempat_lahir','')),''),
                nullif(trim(coalesce(r->>'tanggal_lahir','')),'')::date,
                nullif(trim(coalesce(r->>'alamat','')),''),
                nullif(trim(coalesce(r->>'no_hp','')),''));
        v_created := v_created + 1;
      else
        update auth.users
           set encrypted_password = extensions.crypt(v_pass, extensions.gen_salt('bf')),
               updated_at = now()
         where id = v_exist;
        update profiles
           set nama = v_nama, nis = v_nis, updated_at = now()
         where id = v_exist;
        insert into siswa (nis, nisn, nama, profile_id, kelas_id, jenis_kelamin,
                           tempat_lahir, tanggal_lahir, alamat, no_hp)
        values (v_nis,
                nullif(trim(coalesce(r->>'nisn','')),''),
                v_nama, v_exist, v_kelas,
                nullif(trim(coalesce(r->>'jk','')),''),
                nullif(trim(coalesce(r->>'tempat_lahir','')),''),
                nullif(trim(coalesce(r->>'tanggal_lahir','')),'')::date,
                nullif(trim(coalesce(r->>'alamat','')),''),
                nullif(trim(coalesce(r->>'no_hp','')),''))
        on conflict (nis) do update set
          nisn = excluded.nisn,
          nama = excluded.nama,
          profile_id = excluded.profile_id,
          kelas_id = coalesce(excluded.kelas_id, siswa.kelas_id),
          jenis_kelamin = coalesce(excluded.jenis_kelamin, siswa.jenis_kelamin),
          tempat_lahir = coalesce(excluded.tempat_lahir, siswa.tempat_lahir),
          tanggal_lahir = coalesce(excluded.tanggal_lahir, siswa.tanggal_lahir),
          alamat = coalesce(excluded.alamat, siswa.alamat),
          no_hp = coalesce(excluded.no_hp, siswa.no_hp);
        v_updated := v_updated + 1;
      end if;

    exception when others then
      v_skipped := v_skipped + 1;
      errors := errors || jsonb_build_array(jsonb_build_object('nama', v_nama, 'error', sqlerrm));
    end;
  end loop;

  return jsonb_build_object(
    'created', v_created, 'updated', v_updated, 'skipped', v_skipped,
    'errors', errors);
end;
$$;

-- mapel with logo_url
drop function if exists public.admin_import_mapel(jsonb);
create or replace function public.admin_import_mapel(p_rows jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  r jsonb; v_nama text; v_jid uuid;
  v_created int := 0;
begin
  if not public.is_admin() then
    raise exception 'Hanya admin yang dapat mengimpor mapel';
  end if;

  for r in select * from jsonb_array_elements(p_rows) loop
    v_nama := trim(coalesce(r->>'nama',''));
    if v_nama = '' then continue; end if;

    v_jid := null;
    if coalesce(r->>'jurusan','') <> '' then
      select id into v_jid from jurusan where lower(trim(nama)) = lower(trim(r->>'jurusan')) limit 1;
      if not found then
        insert into jurusan(nama, singkatan) values (trim(r->>'jurusan'), '') on conflict do nothing;
        select id into v_jid from jurusan where lower(trim(nama)) = lower(trim(r->>'jurusan')) limit 1;
      end if;
    end if;

    insert into mata_pelajaran(nama, kode, kkm, jurusan_id, logo_url)
    values (v_nama, nullif(trim(coalesce(r->>'kode','')),''),
            coalesce(nullif(r->>'kkm','')::numeric, 75), v_jid,
            nullif(coalesce(r->>'logo_url',''),''))
    on conflict (lower(nama)) do update set
      kode = coalesce(excluded.kode, mata_pelajaran.kode),
      kkm = excluded.kkm,
      jurusan_id = coalesce(excluded.jurusan_id, mata_pelajaran.jurusan_id),
      logo_url = coalesce(excluded.logo_url, mata_pelajaran.logo_url);
    v_created := v_created + 1;
  end loop;

  return jsonb_build_object('imported', v_created);
end;
$$;

grant execute on function public.admin_import_siswa(jsonb, text) to authenticated;
grant execute on function public.admin_import_mapel(jsonb) to authenticated;