-- 0017: simpan_jawaban VALIDASI KETAT — soal harus milik ujian peserta ini
--       (tutup celah injeksi jawaban lintas ujian/soal)
create or replace function public.simpan_jawaban(
  p_peserta uuid, p_soal uuid, p_jawaban text, p_ragu boolean default false)
returns void
language plpgsql security definer set search_path = public as $$
declare v_ujian uuid; v_ok boolean;
begin
  if not public.peserta_milik_saya(p_peserta) then raise exception 'Akses ditolak'; end if;
  select ujian_id into v_ujian
    from public.peserta_ujian
   where id = p_peserta and status = 'mengikuti';
  if v_ujian is null then raise exception 'Tidak sedang mengerjakan'; end if;
  select exists (
    select 1 from public.ujian u
    where u.id = v_ujian and u.soal_list @> array[p_soal]::uuid[]
  ) into v_ok;
  if not v_ok then raise exception 'Soal bukan bagian ujian ini'; end if;
  insert into public.jawaban_siswa(peserta_ujian_id, soal_id, jawaban, ragu_ragu, status)
  values (p_peserta, p_soal, nullif(trim(coalesce(p_jawaban,'')), ''), p_ragu,
          case when nullif(trim(coalesce(p_jawaban,'')), '') is null then 'kosong' else 'dijawab' end)
  on conflict (peserta_ujian_id, soal_id) do update set
    jawaban = excluded.jawaban, ragu_ragu = excluded.ragu_ragu,
    status = excluded.status, updated_at = now();
end;
$$;
grant execute on function public.simpan_jawaban(uuid, uuid, text, boolean) to authenticated;
