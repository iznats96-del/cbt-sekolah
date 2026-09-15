-- 0019: admin perlu bisa MENCIPTAKAN profil utk user lain (user management)
create policy "profiles_admin_all" on public.profiles
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());
