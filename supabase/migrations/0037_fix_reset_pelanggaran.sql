-- 0037: fix admin_reset_peserta — pelanggaran ada di hasil_ujian, bukan peserta_ujian
create or replace function public.admin_reset_peserta(
  p_peserta uuid,
  p_mode text default 'ulang'
)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_ujian uuid; v_guru uuid; v_status text;
begin
  select pu.ujian_id, pu.status, u.guru_id
    into v_ujian, v_status, v_guru
    from public.peserta_ujian pu
    join public.ujian u on u.id = pu.ujian_id
   where pu.id = p_peserta;
  if v_ujian is null then raise exception 'Peserta tidak ditemukan'; end if;
  if not (public.is_admin() or (public.is_guru() and v_guru = auth.uid())) then
    raise exception 'Hanya admin/guru pemilik ujian';
  end if;

  if lower(p_mode) = 'buka' then
    update public.peserta_ujian
       set status='mengikuti', finished_at=null
     where id = p_peserta;
  elsif lower(p_mode) = 'hapus_pelanggaran' then
    update public.hasil_ujian set pelanggaran=0, rincian_pelanggaran=null where peserta_ujian_id = p_peserta;
    update public.peserta_ujian set status='mengikuti', finished_at=null where id = p_peserta and status='selesai';
  else -- ulang: reset total
    delete from public.jawaban_siswa where peserta_ujian_id = p_peserta;
    delete from public.hasil_ujian where peserta_ujian_id = p_peserta;
    update public.peserta_ujian
       set status='belum', started_at=null, finished_at=null, token_used=null
     where id = p_peserta;
  end if;

  select status into v_status from public.peserta_ujian where id = p_peserta;
  return jsonb_build_object('peserta', p_peserta, 'status', v_status, 'mode', p_mode);
end;
$$;

create or replace function public.admin_reset_peserta_bulk(
  p_ujian uuid,
  p_mode text default 'ulang'
)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_guru uuid; n int;
begin
  select guru_id into v_guru from public.ujian where id = p_ujian;
  if v_guru is null then raise exception 'Ujian tidak ditemukan'; end if;
  if not (public.is_admin() or (public.is_guru() and v_guru = auth.uid())) then
    raise exception 'Hanya admin/guru pemilik ujian';
  end if;

  if lower(p_mode) = 'buka' then
    update public.peserta_ujian set status='mengikuti', finished_at=null where ujian_id = p_ujian;
  elsif lower(p_mode) = 'hapus_pelanggaran' then
    update public.hasil_ujian set pelanggaran=0, rincian_pelanggaran=null where peserta_ujian_id in (select id from public.peserta_ujian where ujian_id = p_ujian);
    update public.peserta_ujian set status='mengikuti', finished_at=null where ujian_id = p_ujian and status='selesai';
  else
    delete from public.jawaban_siswa where peserta_ujian_id in (select id from public.peserta_ujian where ujian_id=p_ujian);
    delete from public.hasil_ujian where peserta_ujian_id in (select id from public.peserta_ujian where ujian_id=p_ujian);
    update public.peserta_ujian set status='belum', started_at=null, finished_at=null, token_used=null where ujian_id=p_ujian;
  end if;
  get diagnostics n = row_count;
  return jsonb_build_object('reset', n, 'mode', p_mode);
end;
$$;
