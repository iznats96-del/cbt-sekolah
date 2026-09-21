-- ============================================================
-- CBT 0036: UJIAN MULTI-KELAS + RESET PESERTA PER MURID
--   1) ujian_kelas junction: 1 ujian bisa banyak rombel
--   2) adaptor: fungsi helper + RPC check ikut multi-kelas
--   3) reset per murid: guru/admin reset soal/pelanggaran/timer
-- ============================================================

-- ---------- 1) junction ujian <-> kelas ----------
create table if not exists public.ujian_kelas (
  ujian_id uuid not null references public.ujian(id) on delete cascade,
  kelas_id uuid not null references public.kelas(id) on delete cascade,
  primary key (ujian_id, kelas_id)
);
create index if not exists ix_ujian_kelas_kelas on public.ujian_kelas(kelas_id);

-- migrasi data lama: pindahkan kelas_id tunggal ke junction
insert into public.ujian_kelas (ujian_id, kelas_id)
select id, kelas_id from public.ujian where kelas_id is not null
on conflict do nothing;

-- trigger: sinkronkan kelas_id = first dari junction utk kompat lama
create or replace function public.tg_ujian_kelas_sync_parent()
returns trigger language plpgsql as $$
begin
  update public.ujian set kelas_id = new.kelas_id
   where id = new.ujian_id and kelas_id is null;
  return new;
end$$;
drop trigger if exists tg_ujian_kelas_sync on public.ujian_kelas;
create trigger tg_ujian_kelas_sync after insert on public.ujian_kelas
for each row execute function public.tg_ujian_kelas_sync_parent();

-- ---------- 2) helper: cek apakah ujian mengizinkan kelas siswa ----------
create or replace function public.ujian_izinkan_kelas(p_ujian uuid, p_kelas uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select
    -- tanpa kelas = semua rombel boleh
    not exists (select 1 from public.ujian_kelas where ujian_id = p_ujian)
    or exists (select 1 from public.ujian_kelas where ujian_id = p_ujian and kelas_id = p_kelas)
    -- kompat: fallback ke kelas_id tunggal
    or (select kelas_id from public.ujian where id = p_ujian) = p_kelas
    or (p_kelas is null and exists (select 1 from public.ujian_kelas where ujian_id = p_ujian));
$$;

-- ---------- list ujian_kelas util ----------
create or replace function public.ujian_kelas_ids(p_ujian uuid)
returns uuid[] language sql stable security definer set search_path = public as $$
  select coalesce(
    (select array_agg(kelas_id) from public.ujian_kelas where ujian_id = p_ujian),
    array[(select kelas_id from public.ujian where id = p_ujian)]::uuid[]
  );
$$;

-- ---------- RPC: set daftar kelas utk ujian (admin/guru pemilik) ----------
create or replace function public.ujian_set_kelas(p_ujian uuid, p_kelas uuid[])
returns jsonb
language plpgsql security definer set search_path = public as $$
declare u record;
begin
  select guru_id into u from public.ujian where id = p_ujian;
  if u is null then raise exception 'Ujian tidak ditemukan'; end if;
  if not (public.is_admin() or (public.is_guru() and u.guru_id = auth.uid())) then
    raise exception 'Hanya admin/guru pemilik ujian';
  end if;
  delete from public.ujian_kelas where ujian_id = p_ujian;
  if p_kelas is not null and array_length(p_kelas, 1) > 0 then
    insert into public.ujian_kelas (ujian_id, kelas_id)
    select p_ujian, unnest(p_kelas)
    on conflict do nothing;
    -- sinkron kelas_id tunggal = pertama (compat)
    update public.ujian set kelas_id = p_kelas[1] where id = p_ujian;
  else
    update public.ujian set kelas_id = null where id = p_ujian;
  end if;
  return jsonb_build_object('kelas', coalesce(p_kelas, '{}'::uuid[]));
end;
$$;
grant execute on function public.ujian_set_kelas(uuid, uuid[]) to authenticated;

-- ---------- adaptor: my_ujian_aktif support multi-kelas ----------
create or replace function public.my_ujian_aktif()
returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', u.id,
    'nama', u.nama,
    'mapel', mp.nama,
    'kelas', coalesce(
       (select string_agg(k2.nama, ', ') from public.ujian_kelas uk
        join public.kelas k2 on k2.id = uk.kelas_id where uk.ujian_id = u.id),
       k.nama),
    'kelas_ids', public.ujian_kelas_ids(u.id),
    'tanggal', u.tanggal,
    'sesi', s.nama,
    'alokasi_menit', u.alokasi_menit,
    'jumlah_soal', coalesce(array_length(u.soal_list, 1), 0)
  ) order by u.tanggal desc), '[]'::jsonb)
  from public.ujian u
  left join public.mata_pelajaran mp on mp.id = u.mapel_id
  left join public.kelas k on k.id = u.kelas_id
  left join public.sesi s on s.id = u.sesi_id
  where u.status = 'aktif'
    and (
      not exists (select 1 from public.ujian_kelas uk where uk.ujian_id = u.id)
      or public.ujian_izinkan_kelas(u.id, (select kelas_id from public.siswa where profile_id = auth.uid()))
    );
$$;

-- ---------- adaptor: cek_token support multi-kelas ----------
create or replace function public.cek_token_ujian(p_ujian uuid, p_token text)
returns uuid
language plpgsql security definer
set search_path = public
set timezone = 'Asia/Jakarta'
as $$
declare v_peserta uuid; v_status text; srow record;
begin
  select s.id, s.kelas_id into srow from public.siswa s where s.profile_id = auth.uid() limit 1;
  if srow.id is null then raise exception 'Akun siswa belum terdaftar'; end if;

  select status into v_status from public.ujian where id = p_ujian;
  if v_status is distinct from 'aktif' then raise exception 'Ujian tidak aktif'; end if;
  if not public.ujian_izinkan_kelas(p_ujian, srow.kelas_id) then
    raise exception 'Bukan kelas untuk ujian ini';
  end if;
  if not public.uin_window_ok(p_ujian) then
    raise exception 'Ujian tidak tersedia di luar jadwal (hari/jam yang ditetapkan)';
  end if;

  select id, status into v_peserta, v_status from public.peserta_ujian
    where ujian_id = p_ujian and siswa_id = srow.id limit 1;
  if v_peserta is null then
    insert into public.peserta_ujian(ujian_id, siswa_id, status, started_at, token_used)
    values (p_ujian, srow.id, 'mengikuti', now(), 'BEBAS')
    returning id into v_peserta;
  elsif v_status = 'selesai' then
    raise exception 'Sudah mengerjakan ujian ini';
  else
    update public.peserta_ujian set status='mengikuti', token_used='BEBAS' where id = v_peserta;
  end if;
  return v_peserta;
end;
$$;
grant execute on function public.cek_token_ujian(uuid, text) to authenticated, service_role;

-- ---------- adaptor: terbitkan menyalin ke semua rombel ujian ----------
create or replace function public.terbitkan_nomor_peserta(p_ujian uuid)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  u record; s record;
  n int := 0; v_contoh text := '';
  v_info jsonb;
  v_kelas uuid[];
begin
  select kelas_id, guru_id into u from public.ujian where id = p_ujian;
  if u is null then raise exception 'Ujian tidak ditemukan'; end if;
  if not (public.is_admin() or (public.is_guru() and u.guru_id = auth.uid())) then
    raise exception 'Hanya admin/guru pemilik ujian';
  end if;

  v_kelas := public.ujian_kelas_ids(p_ujian);
  if v_kelas is not null and array_length(v_kelas,1) > 0 then
    for s in select id from public.siswa where kelas_id = any(v_kelas) order by lower(nama) loop
      insert into public.peserta_ujian (ujian_id, siswa_id, status)
      values (p_ujian, s.id, 'belum')
      on conflict (ujian_id, siswa_id) do nothing;
    end loop;
  elsif u.kelas_id is not null then
    for s in select id from public.siswa where kelas_id = u.kelas_id order by lower(nama) loop
      insert into public.peserta_ujian (ujian_id, siswa_id, status)
      values (p_ujian, s.id, 'belum')
      on conflict (ujian_id, siswa_id) do nothing;
    end loop;
  end if;

  v_info := public.isi_nomor_kosong_core();

  update public.peserta_ujian pu
     set nomor_peserta = s.nomor_peserta
    from public.siswa s
   where pu.ujian_id = p_ujian
     and pu.siswa_id = s.id
     and s.nomor_peserta is not null;

  get diagnostics n = row_count;
  select pu.nomor_peserta into v_contoh
    from public.peserta_ujian pu
   where pu.ujian_id = p_ujian
   order by pu.nomor_peserta limit 1;

  return jsonb_build_object(
    'total', (select count(*) from public.peserta_ujian where ujian_id = p_ujian),
    'tambah', n,
    'semester', v_info->>'semester',
    'tahun', v_info->>'tahun',
    'contoh', coalesce(v_contoh, ''),
    'format', 'KODE-S-YYZZ-NN (mis TKJ-1-2627-01, disalin dari data siswa)'
  );
end;
$$;
grant execute on function public.terbitkan_nomor_peserta(uuid) to authenticated;

-- ============================================================
-- RESET PESERTA PER MURID (guru pemilik / admin)
--   p_mode: 'ulang' = kembalikan ke belum + hapus jawaban + hapus nilai
--           'buka'  = kembalikan ke mengikuti (lanjut tanpa hapus jawaban)
--           'hapus_pelanggaran' = nol-kan pelanggaran di hasil_ujian
-- ============================================================
create or replace function public.admin_reset_peserta(
  p_peserta uuid,
  p_mode text default 'ulang'
)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare r record; v_ujian uuid; v_guru uuid; v_status text;
begin
  select pu.ujian_id, pu.status, u.guru_id
    into v_ujian, v_status, v_guru
    from public.peserta_ujian pu
    join public.ujian u on u.id = pu.ujian_id
   where pu.id = p_peserta;
  if v_ujian is null then raise exception 'Peserta tidak ditemukan'; end if;
  if not (public.is_admin() or (public.is_guru() and v_guru = auth.uid())) then
    raise exception 'Hanya admin/guru pemilik ujian';
  end if;

  if lower(p_mode) = 'buka' then
    update public.peserta_ujian
       set status='mengikuti', finished_at=null
     where id = p_peserta;
  elsif lower(p_mode) = 'hapus_pelanggaran' then
    update public.hasil_ujian set pelanggaran=0, rincian_pelanggaran=null where peserta_ujian_id = p_peserta;
    update public.peserta_ujian set status='mengikuti', finished_at=null where id = p_peserta and status='selesai';
  else -- ulang: reset total
    delete from public.jawaban_siswa where peserta_ujian_id = p_peserta;
    delete from public.hasil_ujian where peserta_ujian_id = p_peserta;
    update public.peserta_ujian
       set status='belum', started_at=null, finished_at=null, pelanggaran=0, token_used=null
     where id = p_peserta;
  end if;

  select status into v_status from public.peserta_ujian where id = p_peserta;
  return jsonb_build_object('peserta', p_peserta, 'status', v_status, 'mode', p_mode);
end;
$$;
grant execute on function public.admin_reset_peserta(uuid, text) to authenticated;

-- bulk reset per ujian (opsional filter status/k elas)
create or replace function public.admin_reset_peserta_bulk(
  p_ujian uuid,
  p_mode text default 'ulang'
)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_guru uuid; n int;
begin
  select guru_id into v_guru from public.ujian where id = p_ujian;
  if v_guru is null then raise exception 'Ujian tidak ditemukan'; end if;
  if not (public.is_admin() or (public.is_guru() and v_guru = auth.uid())) then
    raise exception 'Hanya admin/guru pemilik ujian';
  end if;

  if lower(p_mode) = 'buka' then
    update public.peserta_ujian set status='mengikuti', finished_at=null where ujian_id = p_ujian;
  elsif lower(p_mode) = 'hapus_pelanggaran' then
    update public.hasil_ujian set pelanggaran=0, rincian_pelanggaran=null where peserta_ujian_id in (select id from public.peserta_ujian where ujian_id = p_ujian);
    update public.peserta_ujian set status='mengikuti', finished_at=null where ujian_id = p_ujian and status='selesai';
  else
    delete from public.jawaban_siswa where peserta_ujian_id in (select id from public.peserta_ujian where ujian_id=p_ujian);
    delete from public.hasil_ujian where peserta_ujian_id in (select id from public.peserta_ujian where ujian_id=p_ujian);
    update public.peserta_ujian set status='belum', started_at=null, finished_at=null, pelanggaran=0, token_used=null where ujian_id=p_ujian;
  end if;
  get diagnostics n = row_count;
  return jsonb_build_object('reset', n, 'mode', p_mode);
end;
$$;
grant execute on function public.admin_reset_peserta_bulk(uuid, text) to authenticated;

-- RLS: admin/guru boleh baca ujian_kelas
alter table public.ujian_kelas enable row level security;
drop policy if exists "uk_read_all" on public.ujian_kelas;
create policy "uk_read_all" on public.ujian_kelas for select using (true);
drop policy if exists "uk_write_admin_guru" on public.ujian_kelas;
create policy "uk_write_admin_guru" on public.ujian_kelas for all using (public.is_admin() or public.is_guru()) with check (public.is_admin() or public.is_guru());
