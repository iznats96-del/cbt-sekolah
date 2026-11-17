-- 0051: rekap_detail sertakan benar_item, jml_item, nilai_soal untuk jodoh.
CREATE OR REPLACE FUNCTION public.rekap_detail(p_ujian uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'Asia/Jakarta'
AS $function$
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
            'bobot', s.bobot,
            'jml_item', CASE WHEN s.jenis = 'jodoh' AND jsonb_typeof(s.kunci->'map') = 'object'
              THEN (SELECT count(*)::int FROM jsonb_object_keys(s.kunci->'map')) ELSE NULL END,
            'benar_item', CASE WHEN s.jenis = 'jodoh' AND jsonb_typeof(s.kunci->'map') = 'object'
              AND j.jawaban IS NOT NULL AND j.jawaban ~ '^\s*\{'
              THEN (SELECT count(*)::int FROM jsonb_object_keys(s.kunci->'map') k
                    WHERE (j.jawaban::jsonb)->>k = (s.kunci->'map')->>k)
              ELSE NULL END,
            'nilai_soal', CASE WHEN s.jenis = 'jodoh' AND jsonb_typeof(s.kunci->'map') = 'object'
              AND j.jawaban IS NOT NULL AND j.jawaban ~ '^\s*\{'
              THEN round((((SELECT count(*)::numeric FROM jsonb_object_keys(s.kunci->'map') k
                    WHERE (j.jawaban::jsonb)->>k = (s.kunci->'map')->>k)
                    / NULLIF((SELECT count(*)::numeric FROM jsonb_object_keys(s.kunci->'map')),0)) * s.bobot)::numeric, 2)
              ELSE NULL END,
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
$function$

