-- ============================================================
-- CBT 0029: ADMIN HAPUS MAPEL (CASCADE) + HAPUS UJIAN (sudah ada 0020)
-- Admin full access: hapus mapel sekalian ujian, soal, peserta,
-- jawaban, hasil yang terkait. Guru hanya mapel/ujian miliknya.
-- ============================================================

-- (1) Hapus MAPEL + semua turunannya (ujian -> peserta -> jawaban/hasil, bank_soal)
create or replace function public.admin_hapus_mapel(p_mapel uuid)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_ujian uuid; v_uj_count int := 0; v_soal_count int := 0;
begin
  if not public.is_admin() then raise exception 'Hanya admin'; end if;

  -- hapus tiap ujian yang pakai mapel ini (pakai admin_hapus_ujian logic)
  for v_ujian in select id from public.ujian where mapel_id = p_mapel loop
    delete from public.jawaban_siswa
      where peserta_ujian_id in (select id from public.peserta_ujian where ujian_id = v_ujian);
    delete from public.hasil_ujian
      where peserta_ujian_id in (select id from public.peserta_ujian where ujian_id = v_ujian);
    delete from public.peserta_ujian where ujian_id = v_ujian;
    delete from public.ujian where id = v_ujian;
    v_uj_count := v_uj_count + 1;
  end loop;

  -- hapus bank soal mapel ini
  select count(*) into v_soal_count from public.bank_soal where mapel_id = p_mapel;
  delete from public.bank_soal where mapel_id = p_mapel;

  -- hapus jadwal pelajaran mapel ini
  delete from public.jadwal_mapel where mapel_id = p_mapel;

  -- terakhir mapel
  delete from public.mata_pelajaran where id = p_mapel;

  return jsonb_build_object('ujian_dihapus', v_uj_count, 'soal_dihapus', v_soal_count);
end;
$$;

grant execute on function public.admin_hapus_mapel(uuid) to authenticated, service_role;

-- (2) Hapus KELAS/ROMBEL + opsi paksa (kalau masih ada siswa, tolak kecuali p_paksa)
create or replace function public.admin_hapus_kelas(p_kelas uuid, p_paksa boolean default false)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_siswa int;
begin
  if not public.is_admin() then raise exception 'Hanya admin'; end if;
  select count(*) into v_siswa from public.siswa where kelas_id = p_kelas;
  if v_siswa > 0 and not p_paksa then
    raise exception 'Rombel masih berisi % siswa', v_siswa;
  end if;
  delete from public.jadwal_mapel where kelas_id = p_kelas;
  delete from public.kelas where id = p_kelas;
  return jsonb_build_object('siswa_terdampak', v_siswa);
end;
$$;

grant execute on function public.admin_hapus_kelas(uuid, boolean) to authenticated, service_role;
