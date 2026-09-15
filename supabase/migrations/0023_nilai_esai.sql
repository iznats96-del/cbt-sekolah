-- 0023: penilaian campur — essay bisa dikoreksi guru (0..10 per butir)
alter table public.jawaban_siswa add column if not exists nilai numeric;

-- guru/admin boleh update baris jawaban dari ujian yang dia pegang
drop policy if exists "jwbn_koreksi_guru" on public.jawaban_siswa;
create policy "jwbn_koreksi_guru" on public.jawaban_siswa
for update to authenticated
using (
  public.is_admin() or (
    public.is_guru() and exists (
      select 1 from public.peserta_ujian p
      join public.ujian u on u.id = p.ujian_id
      where p.id = jawaban_siswa.peserta_ujian_id and u.guru_id = auth.uid())
  )
);
drop policy if exists "jwbn_select_koreksi" on public.jawaban_siswa;
create policy "jwbn_select_koreksi" on public.jawaban_siswa
for select to authenticated
using (
  public.is_admin() or (
    public.is_guru() and exists (
      select 1 from public.peserta_ujian p
      join public.ujian u on u.id = p.ujian_id
      where p.id = jawaban_siswa.peserta_ujian_id and u.guru_id = auth.uid())
  )
);

-- RPC koreksi esai utk guru: set nilai lalu hitung ulang hasil peserta
create or replace function public.koreksi_esai(p_jawaban uuid, p_nilai numeric)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_p uuid; v_own_ok boolean;
begin
  select peserta_ujian_id into v_p from public.jawaban_siswa where id = p_jawaban;
  if v_p is null then raise exception 'Jawaban tidak ditemukan'; end if;
  select exists (
    select 1 from public.peserta_ujian p
    join public.ujian u on u.id = p.ujian_id
    where p.id = v_p and (
      public.is_admin() or (public.is_guru() and u.guru_id = auth.uid())
    )
  ) into v_own_ok;
  if not v_own_ok then raise exception 'Bukan wewenang guru ini'; end if;
  update public.jawaban_siswa set nilai = least(10, greatest(0, coalesce(p_nilai,0)))
   where id = p_jawaban;
  perform public.hitung_nilai(v_p);
  return jsonb_build_object('ok', true);
end;
$$;
grant execute on function public.koreksi_esai(uuid, numeric) to authenticated;
