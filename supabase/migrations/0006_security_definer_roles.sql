-- ============================================================
-- CBT SEKOLAH - 0006
-- 1) is_admin/is_guru/is_siswa -> SECURITY DEFINER
--    (mencegah rekursi RLS: policy profiles -> function -> profiles)
-- 2) admin_import_mapel -> ON CONFLICT (lower(nama)) (bukan nama constraint)
-- ============================================================

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;
create or replace function public.is_guru()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'guru');
$$;
create or replace function public.is_siswa()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'siswa');
$$;

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

    insert into mata_pelajaran(nama, kode, kkm, jurusan_id)
    values (v_nama, nullif(trim(coalesce(r->>'kode','')),''),
            coalesce(nullif(r->>'kkm','')::numeric, 75), v_jid)
    on conflict (lower(nama)) do update set
      kode = coalesce(excluded.kode, mata_pelajaran.kode),
      kkm = excluded.kkm,
      jurusan_id = coalesce(excluded.jurusan_id, mata_pelajaran.jurusan_id);
    v_created := v_created + 1;
  end loop;

  return jsonb_build_object('imported', v_created);
end;
$$;

grant execute on function public.admin_import_mapel(jsonb) to authenticated;