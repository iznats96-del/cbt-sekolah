-- ============================================================
-- CBT SEKOLAH - 0014: NOMOR PESERTA + PASSWORD YPu0001 + REKAM PASSWORD AWAL
--   1) admin_import_siswa: pw awal = 'YP' + 4 digit random bila tidak
--      diberikan; pw TIDAK di-reset saat re-import (kecuali diisi custom)
--   2) profiles.pw_default menyimpan password awal utk walas distribusi
--   3) terbitkan_nomor_peserta(ujian): 001.. per rombel urut nama
--   4) reset_password_siswa(siswa): ganti pw -> YPu0001 baru, dikembalikan dlm teks
-- ============================================================

alter table public.profiles add column if not exists pw_default text;

-- (1+2) fungsi import v3 ------------------------------------------
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

      v_exist := null;
      if v_nis <> '' then
        select profile_id into v_exist from siswa where nis = v_nis;
        if v_exist is null then
          select id into v_exist from profiles where nis = v_nis;
        end if;
      end if;

      if v_exist is null and v_nis = '' then
        select s.profile_id, s.nis into v_exist, v_nis2
          from siswa s
         where lower(trim(s.nama)) = lower(trim(v_nama))
           and (v_kelas is null or s.kelas_id = v_kelas)
         limit 1;
        if v_exist is not null then v_nis := coalesce(v_nis2,''); end if;
      end if;

      -- password awal: custom ? custom : YPu0001 4-digit random per siswa
      if coalesce(p_password,'') <> '' then
        v_pass := p_password;
      elsif v_exist is null then
        v_pass := 'YP'||(1000 + floor(random()*9000))::int;
      end if;

      if v_nis = '' and v_exist is null then
        v_nis := 'N' || lpad(nextval('public.nis_seq')::text, 5, '0');
      end if;
      v_email := lower(replace(v_nis,' ','')) || '@cbt.local';

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

        insert into profiles(id, role, nama, nis, email_show, pw_default)
        values (v_uid, 'siswa', v_nama, v_nis, v_email, v_pass);

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
        -- akun lama: JANGAN reset password kecuali custom diisi
        if coalesce(p_password,'') <> '' then
          update auth.users
             set encrypted_password = extensions.crypt(v_pass, extensions.gen_salt('bf')),
                 updated_at = now()
           where id = v_exist;
        else
          v_pass := null;
        end if;
        update profiles
           set nama = v_nama, nis = v_nis, updated_at = now(),
               pw_default = coalesce(v_pass, pw_default)
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
    'errors', errors,
    'catatan', 'Password awal baru = YPu0001 (lihat kolom password di daftar siswa)');
end;
$$;

-- (3) terbitkan nomor peserta urut nama per rombel -----------------
create or replace function public.terbitkan_nomor_peserta(p_ujian uuid)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  u record; n int := 0; c int := 0; s record;
begin
  select kelas_id, guru_id into u from ujian where id = p_ujian;
  if u is null then raise exception 'Ujian tidak ditemukan'; end if;
  if not (public.is_admin() or (public.is_guru() and u.guru_id = auth.uid())) then
    raise exception 'Hanya admin/guru pemilik ujian';
  end if;

  if u.kelas_id is not null then
    -- daftarkan siswa rombel sbg peserta
    for s in select id from siswa where kelas_id = u.kelas_id order by lower(nama) loop
      insert into public.peserta_ujian (ujian_id, siswa_id, status)
      values (p_ujian, s.id, 'belum')
      on conflict (ujian_id, siswa_id) do nothing;
    end loop;
  end if;
  -- beri nomor urut nama untuk semua peserta tanpa nomor
  n := (select coalesce(max(nomor_peserta::int), 0)
          from public.peserta_ujian
         where ujian_id = p_ujian and nomor_peserta ~ '^\d+$');
  for s in
    select p.siswa_id
    from public.peserta_ujian p
    join public.siswa sw on sw.id = p.siswa_id
    where p.ujian_id = p_ujian and p.nomor_peserta is null
    order by lower(sw.nama)
  loop
    n := n + 1; c := c + 1;
    update public.peserta_ujian
       set nomor_peserta = lpad(n::text, 3, '0')
     where ujian_id = p_ujian and siswa_id = s.siswa_id and nomor_peserta is null;
  end loop;

  return jsonb_build_object(
    'tambah', c,
    'total', (select count(*) from public.peserta_ujian where ujian_id = p_ujian));
end;
$$;

-- (4) reset password siswa -> YPu0001 baru -------------------------
create or replace function public.reset_password_siswa(p_siswa uuid)
returns text
language plpgsql security definer set search_path = public, extensions, auth as $$
declare v_nis text; v_uid uuid; v_pass text;
begin
  if not public.is_admin() then raise exception 'Hanya admin'; end if;
  select nis, profile_id into v_nis, v_uid from siswa where id = p_siswa;
  if v_uid is null then
    select id into v_uid from profiles where nis = v_nis;
  end if;
  if v_uid is null then raise exception 'Siswa belum punya akun login'; end if;
  v_pass := 'YP'||(1000 + floor(random()*9000))::int;
  update auth.users
     set encrypted_password = extensions.crypt(v_pass, extensions.gen_salt('bf')),
         updated_at = now()
   where id = v_uid;
  update profiles set pw_default = v_pass where id = v_uid;
  return v_pass;
end;
$$;

-- tampilkan password awal utk admin (read profiles sendiri: kolom baru)
grant execute on function public.admin_import_siswa(jsonb, text) to authenticated;
grant execute on function public.terbitkan_nomor_peserta(uuid) to authenticated;
grant execute on function public.reset_password_siswa(uuid) to authenticated;

-- daftar semua password awal (khusus admin — cetak daftar utk walas)
create or replace function public.admin_daftar_akun_siswa()
returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'nis', p.nis, 'nama', p.nama, 'pw', p.pw_default,
    'kelas', k.nama) order by k.nama, lower(p.nama)), '[]'::jsonb)
  from public.profiles p
  left join public.siswa s on s.profile_id = p.id
  left join public.kelas k on k.id = s.kelas_id
  where p.role = 'siswa' and public.is_admin();
$$;
grant execute on function public.admin_daftar_akun_siswa() to authenticated;