-- ============================================================
-- CBT SEKOLAH - IMPORT (siswa & mapel) + STORAGE + IMAGE SOAL
-- ============================================================

create extension if not exists pgcrypto with schema extensions;

-- kolom gambar utk soal (sudah ada: gambar_url) & mapel
alter table public.bank_soal add column if not exists gambar_url text;
alter table public.mata_pelajaran add column if not exists logo_url text;

-- unique index mapel by nama (case-insensitive) utk upsert
create unique index if not exists mapel_nama_uniq on public.mata_pelajaran (lower(nama));

-- ============================================================
-- IMPORT SISWA: buat akun auth (email = nis@cbt.local) + profil + siswa
-- password default = NIS bila p_password kosong
-- ============================================================
create or replace function public.admin_import_siswa(p_rows jsonb, p_password text default null)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, auth
as $$
declare
  r jsonb;
  v_nis text; v_nama text; v_email text; v_pass text;
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
    if v_nis = '' then
      v_skipped := v_skipped + 1;
      continue;
    end if;
    if v_nama = '' then v_nama := v_nis; end if;

    v_email := lower(replace(v_nis,' ','')) || '@cbt.local';
    v_pass := coalesce(nullif(p_password,''), v_nis);

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

      -- apakah nis sudah ada?
      select profile_id into v_exist from siswa where nis = v_nis;
      if v_exist is null then
        select id into v_exist from profiles where nis = v_nis;
      end if;

      if v_exist is null then
        -- buat akun auth baru
        v_uid := extensions.gen_random_uuid();
        insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                                email_confirmed_at, created_at, updated_at,
                                confirmation_sent_at, last_sign_in_at,
                                app_metadata, user_metadata)
        values (v_uid, '00000000-0000-0000-0000-000000000000',
                'authenticated', 'authenticated', v_email,
                extensions.crypt(v_pass, extensions.gen_salt('bf')),
                now(), now(), now(), now(), now(),
                '{"provider":"email","providers":["email"]}'::jsonb,
                jsonb_build_object('role','siswa','nama', v_nama));

        insert into auth.identities (id, user_id, provider_id, provider,
                                     identity_data, status, last_sign_in_at,
                                     created_at, updated_at)
        values (extensions.gen_random_uuid(), v_uid, v_uid::text, 'email',
                jsonb_build_object('sub', v_uid::text, 'email', v_email, 'email_verified', true),
                'A', now(), now(), now());

        insert into profiles(id, role, nama, nis, email_show)
        values (v_uid, 'siswa', v_nama, v_nis, v_email);

        v_created := v_created + 1;
        v_exist := v_uid;
      else
        -- reset password & update metadata akun lama
        update auth.users
           set encrypted_password = extensions.crypt(v_pass, extensions.gen_salt('bf')),
               updated_at = now()
         where id = v_exist;
        update profiles
           set nama = v_nama, nis = v_nis, updated_at = now()
         where id = v_exist;
        v_updated := v_updated + 1;
      end if;

      -- upsert data siswa
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
        kelas_id = excluded.kelas_id,
        jenis_kelamin = excluded.jenis_kelamin,
        tempat_lahir = excluded.tempat_lahir,
        tanggal_lahir = excluded.tanggal_lahir,
        alamat = excluded.alamat,
        no_hp = excluded.no_hp;

    exception when others then
      v_skipped := v_skipped + 1;
      errors := errors || jsonb_build_array(jsonb_build_object('nis', v_nis, 'error', sqlerrm));
    end;
  end loop;

  return jsonb_build_object(
    'created', v_created, 'updated', v_updated, 'skipped', v_skipped,
    'errors', errors);
end;
$$;

-- ============================================================
-- IMPORT MAPEL: upsert by nama, jurusan by nama (auto-create)
-- ============================================================
create or replace function public.admin_import_mapel(p_rows jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  r jsonb; v_nama text; v_jid uuid;
  v_created int := 0; v_updated int := 0;
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

    insert into mata_pelajaran(nama, kode, kkm, jurusan_id)
    values (v_nama, nullif(trim(coalesce(r->>'kode','')),''),
            coalesce(nullif(r->>'kkm','')::numeric, 75), v_jid)
    on conflict on constraint mapel_nama_uniq do update set
      kode = coalesce(excluded.kode, mata_pelajaran.kode),
      kkm = excluded.kkm,
      jurusan_id = coalesce(excluded.jurusan_id, mata_pelajaran.jurusan_id);
    v_created := v_created + 1;
  end loop;

  return jsonb_build_object('imported', v_created);
end;
$$;

grant execute on function public.admin_import_siswa(jsonb, text) to authenticated;
grant execute on function public.admin_import_mapel(jsonb) to authenticated;

-- ============================================================
-- STORAGE: bucket 'soal' (gambar soal/logo)
-- ============================================================
insert into storage.buckets (id, name, public)
values ('soal','soal', true)
on conflict (id) do nothing;

drop policy if exists "soal_public_read" on storage.objects;
create policy "soal_public_read" on storage.objects
  for select using (bucket_id = 'soal');

drop policy if exists "soal_upload" on storage.objects;
create policy "soal_upload" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'soal' and (public.is_admin() or public.is_guru()));

drop policy if exists "soal_delete" on storage.objects;
create policy "soal_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'soal' and (public.is_admin() or public.is_guru()));