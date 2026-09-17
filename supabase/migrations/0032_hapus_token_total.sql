-- ============================================================
-- CBT 0032: HAPUS TOTAL SISTEM TOKEN
--   cek_token_ujian: TIDAK lagi memeriksa token sama sekali.
--   Murid langsung masuk selama: ujian aktif + kelas cocok + jam/jadwal buka.
-- ============================================================

create or replace function public.cek_token_ujian(p_ujian uuid, p_token text)
returns uuid
language plpgsql security definer
set search_path = public
set timezone = 'Asia/Jakarta'
as $$
declare v_peserta uuid; v_status text; v_kelas uuid; srow record;
begin
  select s.id, s.kelas_id into srow from public.siswa s where s.profile_id = auth.uid() limit 1;
  if srow.id is null then raise exception 'Akun siswa belum terdaftar'; end if;

  select status, kelas_id into v_status, v_kelas from public.ujian where id = p_ujian;
  if v_status is distinct from 'aktif' then raise exception 'Ujian tidak aktif'; end if;
  if v_kelas is not null and srow.kelas_id is distinct from v_kelas then
    raise exception 'Bukan kelas untuk ujian ini';
  end if;
  if not public.uin_window_ok(p_ujian) then
    raise exception 'Ujian tidak tersedia di luar jadwal (hari/jam yang ditetapkan)';
  end if;
  -- ===== TOKEN DIABAIKAN TOTAL (sistem tanpa token) =====

  select id, status into v_peserta, v_status from public.peserta_ujian
    where ujian_id = p_ujian and siswa_id = srow.id limit 1;
  if v_peserta is null then
    insert into public.peserta_ujian(ujian_id, siswa_id, status, started_at, token_used)
    values (p_ujian, srow.id, 'mengikuti', now(), 'BEBAS')
    returning id into v_peserta;
  elsif v_status = 'selesai' then
    raise exception 'Sudah mengerjakan ujian ini';
  else
    update public.peserta_ujian set status='mengikuti', token_used='BEBAS' where id = v_peserta;
  end if;
  return v_peserta;
end;
$$;
grant execute on function public.cek_token_ujian(uuid, text) to authenticated, service_role;

-- Kosongkan token semua ujian yang ada (biar seragam "tanpa token")
update public.ujian set token = '' where token is not null and btrim(token) <> '';
