-- ============================================================
-- CBT SEKOLAH - 0009: KUNCI JAWABAN OLEH GURU
--  - guru boleh update bank_soal milik ujian yang dia pegang
--    (RLS policy tambahan; untuk isi kunci via UI)
--  - hitung_nilai: PG + JODOH auto-korek (kunci.jawaban), essay manual
-- ============================================================

drop policy if exists "soal_guru_kunci_update" on public.bank_soal;
create policy "soal_guru_kunci_update" on public.bank_soal
for update to authenticated
using (
  public.is_guru() and exists (
    select 1 from public.ujian u
     where u.soal_list @> array[public.bank_soal.id]::uuid[]
       and u.guru_id = auth.uid()
  )
) with check (
  public.is_guru() and exists (
    select 1 from public.ujian u
     where u.soal_list @> array[public.bank_soal.id]::uuid[]
       and u.guru_id = auth.uid()
  )
);

-- juga boleh SIMPAN/LIHAT (select) semua soal utk ujian pegangannya
drop policy if exists "soal_guru_ujian_select" on public.bank_soal;
create policy "soal_guru_ujian_select" on public.bank_soal
for select to authenticated
using (
  public.is_guru() and exists (
    select 1 from public.ujian u
     where u.soal_list @> array[public.bank_soal.id]::uuid[]
       and u.guru_id = auth.uid()
  )
);

create or replace function public.hitung_nilai(p_peserta uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_jumlah_benar int := 0;
  v_jumlah_salah int := 0;
  v_jumlah_kosong int := 0;
  v_skor numeric := 0;
  v_total_bobot numeric := 0;
  v_nilai numeric := 0;
  r record;
  kunci_jawaban text;
  jawaban_val text;
begin
  delete from public.hasil_ujian where peserta_ujian_id = p_peserta;

  for r in
    select s.id as soal_id, s.jenis, s.kunci, s.bobot, j.jawaban
    from public.peserta_ujian pu
    join public.ujian u on u.id = pu.ujian_id
    join public.bank_soal s on s.id = any(u.soal_list)
    left join public.jawaban_siswa j on j.peserta_ujian_id = pu.id and j.soal_id = s.id
    where pu.id = p_peserta
  loop
    v_total_bobot := v_total_bobot + coalesce(r.bobot, 1);
    jawaban_val := nullif(trim(coalesce(r.jawaban, '')), '');

    if r.jenis in ('pg', 'jodoh') then
      kunci_jawaban := r.kunci->>'jawaban';
      if kunci_jawaban is null or kunci_jawaban = '' then
        v_jumlah_kosong := v_jumlah_kosong + 1; -- belum dikunci -> ikut koreksi manual
      elsif jawaban_val is null then
        v_jumlah_kosong := v_jumlah_kosong + 1;
      elsif lower(trim(jawaban_val)) = lower(trim(kunci_jawaban)) then
        v_jumlah_benar := v_jumlah_benar + 1;
        v_skor := v_skor + coalesce(r.bobot, 1);
      else
        v_jumlah_salah := v_jumlah_salah + 1;
      end if;
    else
      -- essay: tidak auto; dihitung di sisi koreksi manual guru
      if jawaban_val is null then
        v_jumlah_kosong := v_jumlah_kosong + 1;
      else
        v_jumlah_kosong := v_jumlah_kosong + 0; -- terjawab tapi butuh nilai manual
      end if;
    end if;
  end loop;

  if v_total_bobot > 0 then
    v_nilai := round((v_skor / v_total_bobot * 100)::numeric, 1);
  end if;

  insert into public.hasil_ujian (
    peserta_ujian_id, jumlah_benar, jumlah_salah, jumlah_kosong, skor, nilai, dinilai
  ) values (
    p_peserta, v_jumlah_benar, v_jumlah_salah, v_jumlah_kosong, v_skor, v_nilai, false
  );
end;
$$;

grant execute on function public.hitung_nilai(uuid) to authenticated;

-- hitung ulang nilai semua peserta SELESAI di satu ujian (dipanggil guru sehabis simpan kunci)
create or replace function public.hitung_ujian(p_ujian uuid)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  c int := 0;
  r record;
begin
  if not (public.is_admin() or public.is_guru()) then
    raise exception 'Hanya admin/guru';
  end if;
  for r in select id from peserta_ujian where ujian_id = p_ujian and status = 'selesai' loop
    begin
      perform public.hitung_nilai(r.id);
      c := c + 1;
    exception when others then
      null;
    end;
  end loop;
  return c;
end;
$$;

grant execute on function public.hitung_ujian(uuid) to authenticated;