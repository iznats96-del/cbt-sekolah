-- 0025: admin_daftar_akun_siswa pakai RAISE utk non-admin (jwb tegas 400)
create or replace function public.admin_daftar_akun_siswa()
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare res jsonb;
begin
  if not public.is_admin() then raise exception 'Hanya admin'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'nis', p.nis, 'nama', p.nama, 'pw', p.pw_default, 'kelas', k.nama)
    order by k.nama, lower(p.nama)), '[]'::jsonb)
    into res
  from public.profiles p
  left join public.siswa s on s.profile_id = p.id
  left join public.kelas k on k.id = s.kelas_id
  where p.role = 'siswa';
  return res;
end;
$$;
grant execute on function public.admin_daftar_akun_siswa() to authenticated;
