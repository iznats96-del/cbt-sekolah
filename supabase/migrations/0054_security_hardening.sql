-- CBT 0054: security hardening hasil audit penuh
-- 1) Cabut grant RPC admin & hitung_nilai dari public/anon/authenticated.
--    Semua RPC ini SECURITY DEFINER, pemanggilan internal tetap jalan.
do $$
declare r record;
begin
  for r in
    select oid, proname, pg_get_function_identity_arguments(oid) as args
    from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname in (
        'admin_buat_akun', 'admin_reset_pw', 'admin_hapus_akun',
        'hitung_nilai'
      )
  loop
    execute format(
      'revoke all on function public.%I(%s) from public, anon, authenticated',
      r.proname, r.args
    );
  end loop;
end $$;

-- 2) Cegah eskalasi role lewat profiles_update_own.
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create or replace function public.guard_profiles_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if (
    new.role is distinct from old.role
    or new.guru_id is distinct from old.guru_id
    or new.siswa_id is distinct from old.siswa_id
    or new.nis is distinct from old.nis
  )
  and not public.is_admin()
  and coalesce(auth.jwt()->>'role', '') not in ('service_role', 'supabase_admin')
  then
    raise exception 'Tidak diizinkan mengubah role/identitas akun';
  end if;
  return new;
end $$;

drop trigger if exists guard_profiles_role on public.profiles;
create trigger guard_profiles_role
  before update on public.profiles
  for each row execute function public.guard_profiles_role();
