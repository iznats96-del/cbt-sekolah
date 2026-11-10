-- ============================================================
-- CBT SEKOLAH - FUNGSI PENILAIAN
-- hitung_nilai: hitung skor otomatis untuk PG, essay dinilai manual oleh guru
-- panggil saat peserta mengumpulkan ujian (dari app siswa)
-- ============================================================

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
  v_nilai numeric := 0;
  v_total_soal int := 0;
  r record;
  kunci_val text;
  jawaban_val text;
  benar boolean;
  jodoh_benar boolean;
  kunci_map jsonb;
  jawaban_map jsonb;
  k text;
  v text;
begin
  -- reset hasil lama
  delete from public.hasil_ujian where peserta_ujian_id = p_peserta;

  -- ambil daftar soal ujian via peserta -> ujian -> soal_list
  for r in
    select s.id as soal_id, s.jenis, s.kunci, s.bobot, j.jawaban
    from public.peserta_ujian pu
    join public.ujian u on u.id = pu.ujian_id
    join public.bank_soal s on s.id = any(u.soal_list)
    left join public.jawaban_siswa j on j.peserta_ujian_id = pu.id and j.soal_id = s.id
    where pu.id = p_peserta
  loop
    v_total_soal := v_total_soal + 1;
    jawaban_val := r.jawaban;
    kunci_val := null;

    if r.jenis = 'pg' then
      -- PG: kunci = {"index":..., "jawaban":...} -> cocokkan teks (case-insensitive)
      kunci_val := r.kunci->>'jawaban';
      if jawaban_val is null or jawaban_val = '' then
        v_jumlah_kosong := v_jumlah_kosong + 1;
      else
        benar := lower(trim(jawaban_val)) = lower(trim(coalesce(kunci_val, '')));
        if benar then
          v_jumlah_benar := v_jumlah_benar + 1;
          v_skor := v_skor + coalesce(r.bobot, 1);
        else
          v_jumlah_salah := v_jumlah_salah + 1;
        end if;
      end if;

    elsif r.jenis = 'jodoh' then
      -- ============================================================
      -- JODOH MULTI-PAIR: 1 soal = N pasangan (A1..An vs B diacak).
      -- - kunci->'map' = JSON string '{"0":"bIdx","1":"bIdx",...}'
      --   (key = index A 0-based, value = index B 0-based baris)
      -- - jawaban siswa = JSON string indexA->indexB (dari UI siswa)
      -- - SKORING: SOAL BENAR hanya jika SETIAP pasangan A->B yang
      --   siswa pilih COCOK sama kunci->>'map'.
      -- - Legacy (jodoh lama simpan teks B tunggal): fallback cocokkan
      --   teks case-insensitive, sama seperti format {jawaban: teks}.
      -- ============================================================
      jodoh_benar := false;
      if jawaban_val is null or jawaban_val = '' then
        v_jumlah_kosong := v_jumlah_kosong + 1;
      else
        -- Apakah kunci pakai format baru ({map: ...})?
        -- Simpan: kunci::jsonb = {"map": "{\"0\":\"3\",...}"}
        -- ->'map' menghasilkan jsonb STRING -> parse lagi ::jsonb jadi objek.
        kunci_map := null;
        begin
          kunci_map := (r.kunci->'map')::jsonb;
        exception
          when others then
            kunci_map := null;
        end;

        if kunci_map is not null then
          -- FORMAT BARU: cocokkan peta A->B secara lengkap.
          begin
            jawaban_map := jsonb(jawaban_val);
          exception
            when others then
              -- jawaban bukan JSON map (legacy teks) -> coba fallback di bawah
              jawaban_map := null;
            end;

          if jawaban_map is not null then
            -- Cek SEMUA A yang ada di kunci: siswa harus pilih B yang sama.
            jodoh_benar := true;
            for k in select key from jsonb_object_keys(kunci_map)
            loop
              v := jawaban_map->>k;  -- value di jawaban (teks index B), null jika A tsb belum dijawab
              if v is distinct from kunci_map->>k then
                jodoh_benar := false;
                exit;
              end if;
            end loop;
            -- Soal jodoh benar hanya jika semua pasangan cocok.
            if jodoh_benar then
              v_jumlah_benar := v_jumlah_benar + 1;
              v_skor := v_skor + coalesce(r.bobot, 1);
            else
              v_jumlah_salah := v_jumlah_salah + 1;
            end if;
          else
            -- Jawaban bukan JSON map -> anggap belum terjawab (legacy)
            v_jumlah_kosong := v_jumlah_kosong + 1;
          end if;
        else
          -- LEGACY: kunci lama {jawaban: teks} -> cocokkan teks case-insensitive
          kunci_val := coalesce(r.kunci->>'jawaban', '');
          if kunci_val = '' then
            -- jodoh tanpa kunci: exclude dari total
            v_total_soal := v_total_soal - 1;
          else
            benar := lower(trim(jawaban_val)) = lower(trim(kunci_val));
            if benar then
              v_jumlah_benar := v_jumlah_benar + 1;
              v_skor := v_skor + coalesce(r.bobot, 1);
            else
              v_jumlah_salah := v_jumlah_salah + 1;
            end if;
          end if;
        end if;
      end if;

    elsif r.jenis = 'essay' then
      -- essay: tandai belum dinilai; guru menilai manual
      v_jumlah_kosong := v_jumlah_kosong + 1; -- placeholder
    end if;
  end loop;

  -- nilai = skor / total bobot * 100 ; fallback jumlah_benar/total * 100
  if v_total_soal > 0 then
    v_nilai := v_skor / v_total_soal * 100;
  end if;

  insert into public.hasil_ujian (
    peserta_ujian_id, jumlah_benar, jumlah_salah, jumlah_kosong, skor, nilai, dinilai
  ) values (
    p_peserta, v_jumlah_benar, v_jumlah_salah, v_jumlah_kosong, v_skor, v_nilai, false
  );
end;
$$;

grant execute on function public.hitung_nilai(uuid) to authenticated;