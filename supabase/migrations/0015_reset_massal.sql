-- 0015: reset password massal -> YPxxxx (login selalu NIS)
create or replace function public.admin_reset_semua_password(p_kelas_id uuid default null)
returns jsonb
language plpgsql security definer set search_path = public, extensions, auth as $$
declare
  r record; n int := 0; v_pass text;
begin
  if not public.is_admin() then raise exception 'Hanya admin'; end if;
  for r in
    select p.id as uid, p.nis
    from public.profiles p
    join public.siswa s on s.profile_id = p.id
    where p.role = 'siswa' and p.nis is not null
      and (p_kelas_id is null or s.kelas_id = p_kelas_id)
    order by s.nama
  loop
    v_pass := 'YP'||(1000 + floor(random()*9000))::int;
    update auth.users
       set encrypted_password = extensions.crypt(v_pass, extensions.gen_salt('bf')),
           updated_at = now()
     where id = r.uid;
    update public.profiles set pw_default = v_pass where id = r.uid;
    n := n + 1;
  end loop;
  return jsonb_build_object('direset', n);
end;
$$;
grant execute on function public.admin_reset_semua_password(uuid) to authenticated;
