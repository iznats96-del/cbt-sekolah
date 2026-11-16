-- ============================================================
-- 0048: FIX kolom 'benar' di rekap_detail agar SESUAI dgn hitung_nilai
-- Gejala: jawaban "A" (opsi ke-0) vs kunci "PNG" ditandai SALAH,
--         padahal hitung_nilai sudah menghitung BENAR (25/25).
--         Jodoh dengan peta identik juga SALAH karena benar=NULL.
-- Penyebab: rekap_detail membandingkan jawaban mentah dgn teks kunci,
--           tanpa normalisasi huruf->index & tanpa perbandingan peta jodoh.
-- Perbaikan: pakai aturan yang SAMA PERSIS dgn hitung_nilai live:
--   PG    : huruf A-J -> index kunci (ascii-65), atau teks (legacy)
--   Jodoh : cocokkan tiap pasangan peta (bool_and)
--   Essay : NULL (ditampilkan sbg "belum dinilai")
-- Catatan: 0047 (CASE text) sudah termasuk di sini.
-- ============================================================

CREATE OR REPLACE FUNCTION public._rekap_try_jsonb(p_text text)
RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE
SET search_path TO public
AS $$
BEGIN
  IF p_text IS NULL OR btrim(p_text) = '' THEN RETURN NULL; END IF;
  RETURN p_text::jsonb;
EXCEPTION WHEN OTHERS THEN RETURN NULL;
END;
$$;

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
            -- ===== BENAR: mirror logika hitung_nilai =====
            'benar', CASE
              WHEN s.jenis = 'pg' THEN
                COALESCE(
                  CASE
                    WHEN NULLIF(s.kunci ->> 'index', '') IS NOT NULL
                         AND j.jawaban ~ '^[A-Ja-j]$'
                      THEN ((ascii(upper(btrim(j.jawaban))) - 65)::text
                            = (s.kunci ->> 'index'))
                    ELSE NULL
                  END,
                  (NULLIF(btrim(coalesce(j.jawaban, '')), '') IS NOT NULL
                   AND lower(btrim(j.jawaban)) =
                       lower(btrim(coalesce(s.kunci ->> 'jawaban', ''))))
                )
              WHEN s.jenis = 'jodoh'
                   AND jsonb_typeof(s.kunci -> 'map') = 'object' THEN
                COALESCE((
                  SELECT bool_and(public._rekap_try_jsonb(j.jawaban) ->> km.k
                                  = (s.kunci -> 'map') ->> km.k)
                  FROM jsonb_object_keys(s.kunci -> 'map') AS km(k)
                ), false)
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
GRANT EXECUTE ON FUNCTION public._rekap_try_jsonb(text) TO authenticated, service_role;
