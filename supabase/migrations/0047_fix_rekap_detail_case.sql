-- ============================================================
-- 0047: FIX rekap_detail — "CASE types text and jsonb cannot be matched" (42804)
-- Gejala: halaman "Jawaban: ..." (rekap per rombel) error 400 di Supabase.
-- Penyebab: cabang CASE 'kunci' mengembalikan jsonb (s.kunci->'...') di satu
--           cabang dan text (s.kunci->>'...') di cabang lain.
-- Perbaikan: SEMUA hasil CASE di-cast eksplisit ke text (->> / ::text),
--           termasuk 'kunci', 'jawaban', dan 'benar'.
-- Cara pasang: Supabase Dashboard -> SQL Editor -> paste -> Run.
--             Atau: supabase db push / npx supabase db execute --file ...
-- ============================================================

CREATE OR REPLACE FUNCTION public.rekap_detail(p_ujian uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
SET timezone = 'Asia/Jakarta'
AS $$
DECLARE
  out jsonb;
BEGIN
  IF NOT (public.is_admin() OR public.is_guru()) THEN
    RAISE EXCEPTION 'Akses ditolak';
  END IF;

  SELECT COALESCE(jsonb_agg(row_obj ORDER BY urut), '[]'::jsonb) INTO out
  FROM (
    SELECT pu.id AS pid, pu.nomor_peserta, pu.status,
      sw.nama AS nama, sw.nis AS nis,
      jsonb_build_object(
        'peserta_id', pu.id,
        'nama', sw.nama,
        'nis', sw.nis,
        'nomor', pu.nomor_peserta,
        'status', pu.status,
        'nilai', h.nilai,
        'benar', h.jumlah_benar,
        'salah', h.jumlah_salah,
        'kosong', h.jumlah_kosong,
        'detail', COALESCE((
          SELECT jsonb_agg(jsonb_build_object(
            'soal_id', s.id,
            'jenis', s.jenis,
            'soal', s.soal,
            'opsi', s.opsi,
            -- SEMUA cabang CASE -> text (fix 42804)
            'kunci', COALESCE(
              NULLIF(btrim(
                CASE
                  WHEN s.jenis = 'jodoh' AND s.kunci IS NOT NULL
                       AND s.kunci::text LIKE '%map%'
                    THEN (s.kunci -> 'map')::text
                  WHEN s.jenis = 'pg'
                    THEN s.kunci ->> 'jawaban'
                  ELSE COALESCE(s.kunci ->> 'pedoman', s.kunci ->> 'kunci', s.kunci ->> 'jawaban')
                END
              ), ''),
              s.kunci ->> 'jawaban'
            )::text,
            'jawaban', j.jawaban,
            'nilai_esai', j.nilai,
            'benar', CASE
              WHEN s.jenis = 'pg'
                THEN (NULLIF(lower(btrim(COALESCE(j.jawaban, ''))), '') IS NOT NULL
                      AND lower(btrim(COALESCE(j.jawaban, ''))) =
                          lower(btrim(COALESCE(s.kunci ->> 'jawaban', ''))))
              ELSE NULL
            END
          ) ORDER BY o.ordn)
          FROM unnest(u.soal_list) WITH ORDINALITY AS o(sid, ordn)
          JOIN public.bank_soal s ON s.id = o.sid
          LEFT JOIN public.jawaban_siswa j
                 ON j.peserta_ujian_id = pu.id AND j.soal_id = s.id
        ), '[]'::jsonb)
      ) AS row_obj,
      row_number() OVER () AS urut
    FROM public.peserta_ujian pu
    JOIN public.siswa sw ON sw.id = pu.siswa_id
    JOIN public.ujian u ON u.id = pu.ujian_id
    LEFT JOIN public.hasil_ujian h ON h.peserta_ujian_id = pu.id
    WHERE pu.ujian_id = p_ujian
  ) x;

  RETURN out;
END;
$$;

GRANT EXECUTE ON FUNCTION public.rekap_detail(uuid) TO authenticated, service_role;
