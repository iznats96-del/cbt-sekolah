-- 0050: bobot sesuai instruksi kepsek (umum 60/20/20, produktif 60/10/30).
-- Jodoh = 1 soal, bobot 20 (umum) / 10 (produktif), dibagi rata ke pasangan.
CREATE OR REPLACE FUNCTION public.hitung_nilai(p_peserta uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions'
AS $function$
declare
  v_benar int := 0; v_salah int := 0; v_kosong int := 0;
  v_skor numeric := 0; v_total numeric := 0; v_nilai numeric := 0;
  r record;
  kj text;
  jv text;
  es numeric;
  v_soal_list uuid[];
  v_override uuid[];
  v_ujian_id uuid;
  v_siswa_kelas uuid;
  v_kategori text := 'umum';
  v_bobot numeric;
  v_map jsonb;
  k_map jsonb;
  v_n int;
  v_kidx text;
  v_ok boolean;
  v_kunci jsonb;
begin
  select u.soal_list, u.id, s.kelas_id, coalesce(mp.kategori, 'umum')
    into v_soal_list, v_ujian_id, v_siswa_kelas, v_kategori
    from public.peserta_ujian pu
    join public.ujian u on u.id = pu.ujian_id
    left join public.siswa s on s.id = pu.siswa_id
    left join public.mata_pelajaran mp on mp.id = u.mapel_id
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
    select s.id as soal_id, s.jenis, s.kunci, s.bobot as soal_bobot, j.jawaban, j.nilai as esai_nilai
      from public.peserta_ujian pu
      join public.bank_soal s on s.id = any(v_soal_list)
      left join public.jawaban_siswa j on j.peserta_ujian_id = pu.id and j.soal_id = s.id
     where pu.id = p_peserta
  loop
    jv := nullif(trim(coalesce(r.jawaban, '')), '');

    -- Bobot dinamis sesuai kategori mapel + jenis soal
    if v_kategori = 'produktif' then
      v_bobot := case r.jenis
        when 'pg' then 1.5
        when 'jodoh' then 10
        when 'essay' then 3
        else 1 end;
    else
      v_bobot := case r.jenis
        when 'pg' then 2
        when 'jodoh' then 20
        when 'essay' then 4
        else 1 end;
    end if;
    if coalesce(r.soal_bobot, 0) > 0 then
      v_bobot := r.soal_bobot;
    end if;

    -- v_total ditambah di masing-masing cabang:
    --   pg/essay: 1 x bobot ; jodoh: N item kiri x bobot
    -- (baris lama "v_total := v_total + v_bobot" dihapus)

    if r.jenis = 'pg' then
      kj := nullif(btrim(coalesce(r.kunci->>'jawaban', '')), '');
      -- kunci.index = angka (0..), siswa kirim huruf (A..J) -> normalisasi
      v_kidx := nullif(r.kunci->>'index', '');
      if kj is null and v_kidx is null then
        continue; -- tanpa kunci: exclude (total tidak ditambah)
      end if;
      v_total := v_total + v_bobot;
      if jv is null then
        v_kosong := v_kosong + 1;
      else
        v_ok := false;
        -- Cocokkanhuruf siswa (A/B/C) -> index kunci
        if v_kidx is not null and jv ~ '^[A-Ja-j]$' then
          v_ok := ((ascii(upper(jv)) - 65)::text = v_kidx);
        end if;
        -- ATAU cocokkan teks jawaban (legacy / jawaban teks)
        if not v_ok and kj is not null then
          v_ok := (lower(btrim(jv)) = lower(btrim(kj)));
        end if;
        if v_ok then
          v_benar := v_benar + 1;
          v_skor := v_skor + v_bobot;
        else
          v_salah := v_salah + 1;
        end if;
      end if;

    elsif r.jenis = 'jodoh' then
      -- JODOH: 1 bank soal = N item kiri. TIAP item dinilai sendiri.
      -- kunci.map = peta index kiri -> index kanan yang benar.
      begin
        v_kunci := case
          when jsonb_typeof(r.kunci) = 'object' then r.kunci
          else r.kunci::jsonb
        end;
      exception when others then v_kunci := null; end;

      k_map := case
        when v_kunci is not null and jsonb_typeof(v_kunci->'map') = 'object'
          then v_kunci->'map'
        else null end;

      if k_map is null then
        continue; -- tanpa kunci: exclude
      end if;

      select count(*) into v_n from jsonb_object_keys(k_map);
      if v_n = 0 then continue; end if;

      v_total := v_total + v_bobot; -- N item x bobot per item

      begin
        v_map := jv::jsonb;
      exception when others then v_map := null; end;

      if v_map is null or jsonb_typeof(v_map) <> 'object' then
        v_kosong := v_kosong + v_n; -- semua item belum diisi
        continue;
      end if;

      -- cocokkan per item kiri (bukan all-or-nothing)
      for kj in select jsonb_object_keys(k_map) loop
        if v_map->>kj is null or btrim(v_map->>kj) = '' then
          v_kosong := v_kosong + 1;
        elsif v_map->>kj = k_map->>kj then
          v_benar := v_benar + 1;
          v_skor := v_skor + v_bobot / v_n;
        else
          v_salah := v_salah + 1;
        end if;
      end loop;

    else
      -- essay: nilai koreksi 0..10 -> proporsional bobot
      v_total := v_total + v_bobot;
      es := coalesce(r.esai_nilai, 0);
      if jv is null then es := 0; end if;
      v_skor := v_skor + (es / 10.0) * v_bobot;
    end if;
  end loop;

  if v_total > 0 then
    v_nilai := round((v_skor / v_total * 100)::numeric, 1);
  end if;

  insert into public.hasil_ujian
    (peserta_ujian_id, jumlah_benar, jumlah_salah, jumlah_kosong, skor, nilai, dinilai)
  values (p_peserta, v_benar, v_salah, v_kosong, round(v_skor, 2), v_nilai, true)
  on conflict (peserta_ujian_id) do update set
    jumlah_benar = excluded.jumlah_benar,
    jumlah_salah = excluded.jumlah_salah,
    jumlah_kosong = excluded.jumlah_kosong,
    skor = excluded.skor,
    nilai = excluded.nilai,
    dinilai = true;
end;
$function$

