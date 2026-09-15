-- 0022: nilai = skor / TOTAL BOBOT SOAL BERKUNCI saja (pg & jodoh berkunci;
--       essay => ranah koreksi manual guru, tidak memotong nilai PG)
create or replace function public.hitung_nilai(p_peserta uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_benar int := 0; v_salah int := 0; v_kosong int := 0;
  v_skor numeric := 0; v_total numeric := 0; v_nilai numeric := 0;
  v_terkunci int := 0;
  r record; kj text; jv text;
begin
  for r in
    select s.id as soal_id, s.jenis, s.kunci, s.bobot, j.jawaban
    from public.peserta_ujian pu
    join public.ujian u on u.id = pu.ujian_id
    join public.bank_soal s on s.id = any(u.soal_list)
    left join public.jawaban_siswa j on j.peserta_ujian_id = pu.id and j.soal_id = s.id
    where pu.id = p_peserta
  loop
    jv := nullif(trim(coalesce(r.jawaban, '')), '');

    if r.jenis in ('pg', 'jodoh') then
      kj := nullif(btrim(coalesce(r.kunci->>'jawaban', '')), '');
      if kj is null then
        continue; -- belum dikunci: tidak dinilai otomatis
      end if;
      v_terkunci := v_terkunci + 1;
      v_total := v_total + coalesce(r.bobot, 1);
      if jv is null then
        v_kosong := v_kosong + 1;
      elsif lower(btrim(jv)) = lower(btrim(kj)) then
        v_benar := v_benar + 1;
        v_skor := v_skor + coalesce(r.bobot, 1);
      else
        v_salah := v_salah + 1;
      end if;
    else
      if jv is null then v_kosong := v_kosong + 1; end if;
    end if;
  end loop;

  if v_total > 0 then
    v_nilai := round((v_skor / v_total * 100)::numeric, 1);
  end if;

  insert into public.hasil_ujian
    (peserta_ujian_id, jumlah_benar, jumlah_salah, jumlah_kosong, skor, nilai, dinilai)
  values (p_peserta, v_benar, v_salah, v_kosong, v_skor, case when v_terkunci > 0 then v_nilai else 0 end, v_terkunci > 0)
  on conflict (peserta_ujian_id) do update set
    jumlah_benar = excluded.jumlah_benar,
    jumlah_salah = excluded.jumlah_salah,
    jumlah_kosong = excluded.jumlah_kosong,
    skor = excluded.skor,
    nilai = excluded.nilai,
    dinilai = excluded.dinilai;
end;
$$;
grant execute on function public.hitung_nilai(uuid) to authenticated;
