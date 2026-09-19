-- ============================================================
-- CBT 0033: ABSEN ANTI-DUPLIKAT + RPC catat_hadir
--   1) unique(siswa_id, tanggal) -> scan 2x / dobel-tap mustahil dobel baris
--   2) RPC catat_hadir(p_nis, p_status='hadir'): atomik, milik guru/admin,
--      balikin nama + status baru/sudah (dipakai layar scan + presensi manual)
-- ============================================================

-- bersihkan duplikat lama bila ada (simpan 1 terbaru per siswa/hari)
delete from public.kehadiran a using public.kehadiran b
where a.id < b.id
  and a.siswa_id = b.siswa_id
  and a.tanggal = b.tanggal;

alter table public.kehadiran
  add constraint kehadiran_siswa_tanggal_unique unique (siswa_id, tanggal);

create or replace function public.catat_hadir(p_nis text, p_status text default 'hadir')
returns jsonb
language plpgsql security definer
set search_path = public
set timezone = 'Asia/Jakarta'
as $$
declare srow record; kid uuid; v_baru boolean;
begin
  if not (public.is_admin() or public.is_guru()) then
    raise exception 'Hanya guru/admin';
  end if;
  if p_status not in ('hadir','izin','sakit','alpa') then
    raise exception 'Status tidak dikenal';
  end if;

  select s.id, s.nama, s.nis into srow
    from public.siswa s where s.nis = trim(p_nis) limit 1;
  if srow.id is null then
    raise exception 'NIS % tidak terdaftar', trim(p_nis);
  end if;

  select k.id into kid from public.kehadiran k
   where k.siswa_id = srow.id and k.tanggal = current_date limit 1;

  if kid is null then
    insert into public.kehadiran(siswa_id, tanggal, status, guru_id)
    values (srow.id, current_date, p_status, auth.uid())
    returning id into kid;
    v_baru := true;
  else
    update public.kehadiran
       set status = p_status, guru_id = auth.uid()
     where id = kid;
    v_baru := false;
  end if;

  return jsonb_build_object(
    'nama', srow.nama, 'nis', srow.nis,
    'status', p_status, 'baru', v_baru);
exception when unique_violation then
  -- balap tulis (race): ambil baris yang menang lalu update
  select k.id into kid from public.kehadiran k
   where k.siswa_id = srow.id and k.tanggal = current_date limit 1;
  update public.kehadiran set status = p_status, guru_id = auth.uid() where id = kid;
  return jsonb_build_object(
    'nama', srow.nama, 'nis', srow.nis,
    'status', p_status, 'baru', false);
end;
$$;
grant execute on function public.catat_hadir(text, text) to authenticated, service_role;
