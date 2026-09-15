-- 0020: 3 celah dari code-review pra-bot
--  A. kumpulkan_ujian: tolak yang TIDAK sedang mengerjakan (ceguk hasil hantu 0)
--  B. cek_token_ujian: kunci ujian ke KELAS peserta (cegah join lintas rombel dgn token curian)
--  C. simpan_jawaban: batas panjang jawaban (anti pembengkakan payload)

create or replace function public.kumpulkan_ujian(p_peserta uuid)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_status text;
begin
  if not public.peserta_milik_saya(p_peserta) then raise exception 'Akses ditolak'; end if;
  update public.peserta_ujian
     set status = 'selesai', finished_at = now()
   where id = p_peserta and status = 'mengikuti'
  returning status into v_status;
  if v_status is null then raise exception 'Tidak sedang mengerjakan / sudah dikumpulkan'; end if;
  begin
    perform public.hitung_nilai(p_peserta);
  exception when others then null; end;
  return jsonb_build_object('selesai', true);
end;
$$;

create or replace function public.cek_token_ujian(p_ujian uuid, p_token text)
returns uuid
language plpgsql security definer
set search_path = public
set timezone = 'Asia/Jakarta'
as $$
declare v_peserta uuid; v_status text; v_token text; v_kelas uuid; srow record;
begin
  select s.id, s.kelas_id into srow from public.siswa s where s.profile_id = auth.uid() limit 1;
  if srow.id is null then raise exception 'Akun siswa belum terdaftar'; end if;

  select token, status, kelas_id into v_token, v_status, v_kelas from public.ujian where id = p_ujian;
  if v_status is distinct from 'aktif' then raise exception 'Ujian tidak aktif'; end if;
  if v_kelas is not null and srow.kelas_id is distinct from v_kelas then
    raise exception 'Bukan kelas untuk ujian ini';
  end if;
  if not public.uin_window_ok(p_ujian) then
    raise exception 'Ujian tidak tersedia di luar jadwal (hari/jam yang ditetapkan)';
  end if;
  if upper(trim(p_token)) <> upper(trim(v_token)) then raise exception 'Salah token'; end if;

  select id, status into v_peserta, v_status from public.peserta_ujian
    where ujian_id = p_ujian and siswa_id = srow.id limit 1;
  if v_peserta is null then
    insert into public.peserta_ujian(ujian_id, siswa_id, status, started_at, token_used)
    values (p_ujian, srow.id, 'mengikuti', now(), p_token)
    returning id into v_peserta;
  elsif v_status = 'selesai' then
    raise exception 'Sudah mengerjakan ujian ini';
  else
    update public.peserta_ujian set status='mengikuti', token_used=p_token where id = v_peserta;
  end if;
  return v_peserta;
end;
$$;

create or replace function public.simpan_jawaban(
  p_peserta uuid, p_soal uuid, p_jawaban text, p_ragu boolean default false)
returns void
language plpgsql security definer set search_path = public as $$
declare v_ujian uuid; v_ok boolean; v_jaw text := nullif(trim(coalesce(p_jawaban,'')), '');
begin
  if v_jaw is not null and length(v_jaw) > 3000 then
    raise exception 'Jawaban terlalu panjang (maks 3000 karakter)';
  end if;
  if not public.peserta_milik_saya(p_peserta) then raise exception 'Akses ditolak'; end if;
  select ujian_id into v_ujian
    from public.peserta_ujian
   where id = p_peserta and status = 'mengikuti';
  if v_ujian is null then raise exception 'Tidak sedang mengerjakan'; end if;
  select exists (
    select 1 from public.ujian u
    where u.id = v_ujian and u.soal_list @> array[p_soal]::uuid[]
  ) into v_ok;
  if not v_ok then raise exception 'Soal bukan bagian ujian ini'; end if;
  insert into public.jawaban_siswa(peserta_ujian_id, soal_id, jawaban, ragu_ragu, status)
  values (p_peserta, p_soal, v_jaw, p_ragu,
          case when v_jaw is null then 'kosong' else 'dijawab' end)
  on conflict (peserta_ujian_id, soal_id) do update set
    jawaban = excluded.jawaban, ragu_ragu = excluded.ragu_ragu,
    status = excluded.status, updated_at = now();
end;
$$;

grant execute on function public.kumpulkan_ujian(uuid) to authenticated;
grant execute on function public.cek_token_ujian(uuid, text) to authenticated;
grant execute on function public.simpan_jawaban(uuid, uuid, text, boolean) to authenticated;
