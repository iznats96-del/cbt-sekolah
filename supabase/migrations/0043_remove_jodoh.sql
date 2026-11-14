-- 0043: HAPUS TOTAL fitur jodoh dari DB.
-- 1. Hapus semua soal bank_soal jenis 'jodoh'
--    (jawaban_siswa ke soal itu ke-cascade via FK soal_id on delete cascade)
-- 2. Buang id soal jodoh dari ujian.soal_list (dan ujian_soal_kelas.soal_list)
-- 3. Rehitung nilai peserta yang kepengaruhui
-- 4. Re-define hitung_nilai & rekap_detail TANPA cabang jodoh
-- 5. Drop cabang 'jodoh' dari check constraint jenis

begin;

-- (1) kumpulkan id soal jodoh dulu
do $$
declare
  jodoh_ids uuid[];
  affected_peserta uuid[];
  u_row record;
  new_list uuid[];
begin
  select coalesce(array_agg(id), '{}') into jodoh_ids
    from public.bank_soal where jenis = 'jodoh';

  if array_length(jodoh_ids, 1) is null then
    raise notice 'Tidak ada soal jodoh di bank_soal';
  else
    raise notice 'Menghapus % soal jodoh', array_length(jodoh_ids, 1);

    -- peserta yang terdampak (punya jawaban / ikut ujian yang soal_list-nya berisi jodoh)
    select coalesce(array_agg(distinct j.peserta_ujian_id), '{}')
      into affected_peserta
      from public.jawaban_siswa j
     where j.soal_id = any(jodoh_ids);

    -- hapus jawaban siswa terhadap soal jodoh (kalau FK cascade belum berlaku)
    delete from public.jawaban_siswa where soal_id = any(jodoh_ids);

    -- bersihkan soal_list per ujian + rehitung
    for u_row in
      select id, soal_list from public.ujian
       where soal_list && jodoh_ids
    loop
      new_list := array(
        select x from unnest(u_row.soal_list) as t(x)
         where x <> all(jodoh_ids)
      );
      update public.ujian set soal_list = new_list where id = u_row.id;
    end loop;

    -- bersihkan override per kelas
    for u_row in
      select id, soal_list from public.ujian_soal_kelas
       where soal_list && jodoh_ids
    loop
      new_list := array(
        select x from unnest(u_row.soal_list) as t(x)
         where x <> all(jodoh_ids)
      );
      update public.ujian_soal_kelas set soal_list = new_list where id = u_row.id;
    end loop;

    -- hapus soalnya
    delete from public.bank_soal where id = any(jodoh_ids);

    -- (3) rehitung nilai peserta yang terdampak
    if array_length(affected_peserta, 1) is not null then
      for i in 1..array_length(affected_peserta, 1) loop
        perform public.hitung_nilai(affected_peserta[i]);
      end loop;
    end if;
  end if;
end $$;

-- (4) hitung_nilai: re-define tanpa cabang jodoh (jodoh sudah tak ada di data)
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

-- (4b) rekap_detail: bersihkan cabang jodoh
create or replace function public.rekap_detail(p_ujian uuid)
returns jsonb
language plpgsql stable security definer
set search_path = public
set timezone = 'Asia/Jakarta'
as $$
declare out jsonb;
begin
  if not (public.is_admin() or public.is_guru()) then raise exception 'Akses ditolak'; end if;
  select coalesce(jsonb_agg(row_obj order by urut), '[]'::jsonb) into out
  from (
    select pu.id as pid, pu.nomor_peserta, pu.status,
      sw.nama as nama, sw.nis as nis,
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
        'detail', coalesce((
           select jsonb_agg(jsonb_build_object(
             'soal_id', s.id,
             'jenis', s.jenis,
             'soal', s.soal,
             'opsi', s.opsi,
             'kunci', case
               when s.jenis = 'pg' then s.kunci->>'jawaban'
               else s.kunci->>'pedoman'
             end,
             'jawaban', j.jawaban,
             'nilai_esai', j.nilai,
             'benar', case
                 when s.jenis = 'pg'
                   then (nullif(lower(btrim(j.jawaban)),'') is not null
                         and lower(btrim(j.jawaban)) = lower(btrim(s.kunci->>'jawaban')))
                 else null end
           ) order by o.ordn)
           from unnest(u.soal_list) with ordinality as o(sid, ordn)
           join public.bank_soal s on s.id = o.sid
           left join public.jawaban_siswa j on j.peserta_ujian_id = pu.id and j.soal_id = s.id
        ), '[]'::jsonb)
      ) as row_obj,
      row_number() over () as urut
    from public.peserta_ujian pu
    join public.siswa sw on sw.id = pu.siswa_id
    join public.ujian u on u.id = pu.ujian_id
    left join public.hasil_ujian h on h.peserta_ujian_id = pu.id
   where pu.ujian_id = p_ujian
  ) x;
  return out;
end;
$$;
grant execute on function public.rekap_detail(uuid) to authenticated, service_role;

-- (5) enum: hapus 'jodoh' dari check constraint
alter table public.bank_soal
  drop constraint if exists bank_soal_jenis_check;
alter table public.bank_soal
  add constraint bank_soal_jenis_check check (jenis in ('pg','essay'));

commit;
