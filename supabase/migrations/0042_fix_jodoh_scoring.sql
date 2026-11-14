-- 0042: fix skoring jodoh multi-pair (aware ujian_soal_kelas per-kelas)
-- Masalah: form jodoh simpan kunci = {'map': '{"0":"2","1":"0"}'}, tapi
-- hitung_nilai lama cuma cek kunci->>'jawaban' → soal jodoh selalu "tanpa kunci"
-- dan di-exclude dari nilai.
-- Fix:
--   1. Ambil soal_list via override per kelas (ujian_soal_kelas)
--   2. JODOH: cocokkan JSON map siswa vs kunci->'map' (semua pasangan harus cocok)
--      - legacy fallback: kunci->>'jawaban' teks tunggal
--   3. PG: pakai kunci->>'jawaban' (index lama juga didukung)
create or replace function public.hitung_nilai(p_peserta uuid)
 returns void
 language plpgsql
 security definer
 set search_path to 'public', 'extensions'
as $function$
declare
  v_benar int := 0; v_salah int := 0; v_kosong int := 0;
  v_skor numeric := 0; v_total numeric := 0; v_nilai numeric := 0;
  r record; kj text; jv text; es numeric;
  v_soal_list uuid[];
  v_override uuid[];
  v_ujian_id uuid;
  v_siswa_kelas uuid;
begin
  select u.soal_list, u.id, s.kelas_id
    into v_soal_list, v_ujian_id, v_siswa_kelas
    from public.peserta_ujian pu
    join public.ujian u on u.id = pu.ujian_id
    left join public.siswa s on s.id = pu.siswa_id
   where pu.id = p_peserta;

  if v_siswa_kelas is not null and v_ujian_id is not null then
    select soal_list into v_override
      from public.ujian_soal_kelas
     where ujian_id = v_ujian_id and kelas_id = v_siswa_kelas
     limit 1;
    if v_override is not null and array_length(v_override, 1) > 0 then
      v_soal_list := v_override;
    end if;
  end if;

  if v_soal_list is null or array_length(v_soal_list, 1) is null then return; end if;

  for r in
    select s.id as soal_id, s.jenis, s.kunci, s.bobot, j.jawaban, j.id as jwbn_id, j.nilai as esai_nilai
    from public.peserta_ujian pu
    join public.bank_soal s on s.id = any(v_soal_list)
    left join public.jawaban_siswa j on j.peserta_ujian_id = pu.id and j.soal_id = s.id
   where pu.id = p_peserta
  loop
    jv := nullif(trim(coalesce(r.jawaban, '')), '');
    v_total := v_total + coalesce(r.bobot, 1);

    if r.jenis = 'pg' then
      kj := nullif(btrim(coalesce(r.kunci->>'jawaban', '')), '');
      if kj is null then
        v_total := v_total - coalesce(r.bobot, 1); -- soal tanpa kunci tak dihitung
        continue;
      elsif jv is null then
        v_kosong := v_kosong + 1;
      elsif lower(btrim(jv)) = lower(btrim(kj)) then
        v_benar := v_benar + 1;
        v_skor := v_skor + coalesce(r.bobot, 1);
      else
        v_salah := v_salah + 1;
      end if;

    elsif r.jenis = 'jodoh' then
      -- ===== JODOH: DILEMAHKAN =====
      -- Soal jodoh tidak lagi di-score (treat as kosong).
      -- Jika siswa tidak menjawab, hitung sebagai kosong.
      if jv is null then
        v_kosong := v_kosong + 1;
      else
        v_salah := v_salah + 1;
      end if;
    else
      -- esai: skor dari nilai koreksi (0..10) proporsional bobot
      es := coalesce(r.esai_nilai, 0);
      if jv is null then
        es := 0;
      end if;
      v_skor := v_skor + (es / 10.0) * coalesce(r.bobot, 1);
    end if;
  end loop;

  if v_total > 0 then
    v_nilai := round((v_skor / v_total * 100)::numeric, 1);
  end if;

  insert into public.hasil_ujian
    (peserta_ujian_id, jumlah_benar, jumlah_salah, jumlah_kosong, skor, nilai, dinilai)
  values (p_peserta, v_benar, v_salah, v_kosong, round(v_skor,2), v_nilai, true)
  on conflict (peserta_ujian_id) do update set
    jumlah_benar = excluded.jumlah_benar,
    jumlah_salah = excluded.jumlah_salah,
    jumlah_kosong = excluded.jumlah_kosong,
    skor = excluded.skor,
    nilai = excluded.nilai,
    dinilai = true;
end;
$function$;
grant execute on function public.hitung_nilai(uuid) to public;
