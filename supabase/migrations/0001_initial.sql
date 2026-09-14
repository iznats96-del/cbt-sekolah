-- ============================================================
-- CBT SEKOLAH - MIGRASI AWAL
-- Schema inti + RLS per peran (admin / guru / siswa)
-- Eksekusi via Supabase Management API / SQL Editor
-- ============================================================

-- Extensions
create extension if not exists "uuid-ossp";

-- ============================================================
-- PROFIL & PERAN
-- ============================================================
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'siswa' check (role in ('admin','guru','siswa')),
  nama text not null default '',
  nis text unique,
  nisn text,
  email_show text,
  guru_id uuid,
  siswa_id uuid,
  nip text,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ============================================================
-- DATA MASTER
-- ============================================================
create table if not exists public.sekolah (
  id uuid primary key default uuid_generate_v4(),
  nama text not null default '',
  npsn text,
  nss text,
  alamat text,
  telp text,
  email text,
  website text,
  kepala_sekolah text,
  nip_kepala text,
  logo_url text,
  kota text,
  provinsi text,
  status text,
  updated_at timestamptz not null default now()
);

create table if not exists public.tahun_pelajaran (
  id uuid primary key default uuid_generate_v4(),
  nama text not null,
  semester text not null default 'Ganjil',
  is_active boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.jurusan (
  id uuid primary key default uuid_generate_v4(),
  nama text not null,
  singkatan text not null default '',
  deskripsi text,
  created_at timestamptz not null default now()
);

create table if not exists public.mata_pelajaran (
  id uuid primary key default uuid_generate_v4(),
  nama text not null,
  kode text unique,
  jurusan_id uuid references public.jurusan(id) on delete set null,
  kkm numeric not null default 75,
  created_at timestamptz not null default now()
);

create table if not exists public.kelas (
  id uuid primary key default uuid_generate_v4(),
  nama text not null,
  jurusan_id uuid references public.jurusan(id) on delete set null,
  tingkat integer not null default 10,
  tahun_pelajaran_id uuid references public.tahun_pelajaran(id) on delete set null,
  wali_kelas uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.guru (
  id uuid primary key default uuid_generate_v4(),
  profile_id uuid references public.profiles(id) on delete set null,
  nip text unique,
  nama text not null,
  mapel_ids uuid[],  -- id mata_pelajaran yang diampu
  jabatan text,
  created_at timestamptz not null default now()
);

create table if not exists public.siswa (
  id uuid primary key default uuid_generate_v4(),
  profile_id uuid references public.profiles(id) on delete set null,
  nis text unique not null,
  nisn text,
  nama text not null,
  kelas_id uuid references public.kelas(id) on delete set null,
  jenis_kelamin text,
  tempat_lahir text,
  tanggal_lahir date,
  alamat text,
  no_hp text,
  foto_url text,
  aktive_ok boolean not null default true,
  created_at timestamptz not null default now()
);

-- ============================================================
-- DATA E-LEARNING (disiapkan, dipakai bertahap)
-- ============================================================
create table if not exists public.materi (
  id uuid primary key default uuid_generate_v4(),
  judul text not null,
  deskripsi text,
  mapel_id uuid references public.mata_pelajaran(id) on delete cascade,
  kelas_id uuid references public.kelas(id) on delete cascade,
  guru_id uuid references public.profiles(id),
  file_url text,
  tipe text default 'materi',
  created_at timestamptz not null default now()
);

create table if not exists public.tugas (
  id uuid primary key default uuid_generate_v4(),
  judul text not null,
  deskripsi text,
  mapel_id uuid references public.mata_pelajaran(id) on delete cascade,
  kelas_id uuid references public.kelas(id) on delete cascade,
  guru_id uuid references public.profiles(id),
  deadline timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.pengumpulan_tugas (
  id uuid primary key default uuid_generate_v4(),
  tugas_id uuid references public.tugas(id) on delete cascade,
  siswa_id uuid references public.siswa(id) on delete cascade,
  file_url text,
  nilai numeric,
  catatan text,
  submitted_at timestamptz not null default now()
);

create table if not exists public.kehadiran (
  id uuid primary key default uuid_generate_v4(),
  siswa_id uuid references public.siswa(id) on delete cascade,
  tanggal date not null,
  status text not null default 'hadir' check (status in ('hadir','izin','sakit','alpa')),
  keterangan text,
  guru_id uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  unique (siswa_id, tanggal)
);

-- ============================================================
-- DATA UJIAN
-- ============================================================
create table if not exists public.jenis_ujian (
  id uuid primary key default uuid_generate_v4(),
  nama text not null,
  keterangan text,
  created_at timestamptz not null default now()
);

create table if not exists public.ruang (
  id uuid primary key default uuid_generate_v4(),
  nama text not null unique,
  kapasitas integer not null default 30,
  keterangan text,
  created_at timestamptz not null default now()
);

create table if not exists public.bank_soal (
  id uuid primary key default uuid_generate_v4(),
  mapel_id uuid references public.mata_pelajaran(id) on delete cascade,
  jenis text not null default 'pg' check (jenis in ('pg','essay','jodoh')),
  soal text not null,
  opsi jsonb,           -- untuk pg: ["A","B","C","D"]
  kunci jsonb,          -- jawaban benar (pg: {"A":"x"} ; essay: teks; jodoh: {"kiri":"kanan"})
  bobot numeric not null default 1,
  pembahasan text,
  guru_id uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

create table if not exists public.sesi (
  id uuid primary key default uuid_generate_v4(),
  nama text not null,
  jam_mulai time not null,
  jam_selesai time not null,
  keterangan text,
  created_at timestamptz not null default now()
);

create table if not exists public.ujian (
  id uuid primary key default uuid_generate_v4(),
  nama text not null,
  jenis_ujian_id uuid references public.jenis_ujian(id),
  mapel_id uuid references public.mata_pelajaran(id),
  kelas_id uuid references public.kelas(id),
  guru_id uuid references public.profiles(id),
  tanggal date not null,
  sesi_id uuid references public.sesi(id),
  alokasi_menit integer not null default 90,
  token text not null,
  token_digunakan boolean not null default false,
  soal_list uuid[],        -- id bank_soal
  status text not null default 'draft' check (status in ('draft','aktif','selesai','dibatalkan')),
  jenis_penilaian text not null default 'otomatis' check (jenis_penilaian in ('otomatis','manual','campuran')),
  catatan text,
  created_at timestamptz not null default now()
);

create table if not exists public.peserta_ujian (
  id uuid primary key default uuid_generate_v4(),
  ujian_id uuid references public.ujian(id) on delete cascade,
  siswa_id uuid references public.siswa(id) on delete cascade,
  ruang_id uuid references public.ruang(id),
  sesi_id uuid references public.sesi(id),
  nomor_peserta text,
  status text not null default 'belum' check (status in ('belum','mengikuti','selesai','absen','gagal')),
  device_id text,
  started_at timestamptz,
  finished_at timestamptz,
  token_used text,
  created_at timestamptz not null default now(),
  unique (ujian_id, siswa_id)
);

create table if not exists public.atur_ruang_sesi (
  id uuid primary key default uuid_generate_v4(),
  ujian_id uuid references public.ujian(id) on delete cascade,
  ruang_id uuid references public.ruang(id),
  sesi_id uuid references public.sesi(id),
  kapasitas integer not null default 30,
  created_at timestamptz not null default now(),
  unique (ujian_id, ruang_id, sesi_id)
);

-- ============================================================
-- PENGUMPULAN JAWABAN & HASIL
-- ============================================================
create table if not exists public.jawaban_siswa (
  id uuid primary key default uuid_generate_v4(),
  peserta_ujian_id uuid references public.peserta_ujian(id) on delete cascade,
  soal_id uuid references public.bank_soal(id) on delete cascade,
  jawaban text,
  ragu_ragu boolean not null default false,
  waktu_detik integer not null default 0,
  status text not null default 'dijawab' check (status in ('dijawab','kosong')),
  updated_at timestamptz not null default now(),
  unique (peserta_ujian_id, soal_id)
);

create table if not exists public.hasil_ujian (
  id uuid primary key default uuid_generate_v4(),
  peserta_ujian_id uuid references public.peserta_ujian(id) on delete cascade,
  jumlah_benar integer not null default 0,
  jumlah_salah integer not null default 0,
  jumlah_kosong integer not null default 0,
  skor numeric not null default 0,
  nilai numeric not null default 0,
  pelanggaran integer not null default 0,
  rincian_pelanggaran jsonb,
  dinilai boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (peserta_ujian_id)
);

create table if not exists public.pengumuman (
  id uuid primary key default uuid_generate_v4(),
  judul text not null,
  isi text,
  target_role text,
  aktif boolean not null default true,
  created_at timestamptz not null default now()
);

-- ============================================================
-- TRIGGER: updated_at
-- ============================================================
create or replace function public.tg_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end$$;

do $$
declare t text;
begin
  foreach t in array array['profiles','sekolah','tahun_pelajaran','siswa','guru','bank_soal','peserta_ujian','jawaban_siswa','hasil_ujian']
  loop
    execute format('drop trigger if exists tg_%s_updated on public.%I', t, t);
    execute format('create trigger tg_%s_updated before update on public.%I for each row execute function public.tg_updated_at()', t, t);
  end loop;
end$$;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
alter table public.profiles enable row level security;
alter table public.sekolah enable row level security;
alter table public.tahun_pelajaran enable row level security;
alter table public.jurusan enable row level security;
alter table public.mata_pelajaran enable row level security;
alter table public.kelas enable row level security;
alter table public.guru enable row level security;
alter table public.siswa enable row level security;
alter table public.materi enable row level security;
alter table public.tugas enable row level security;
alter table public.pengumpulan_tugas enable row level security;
alter table public.kehadiran enable row level security;
alter table public.jenis_ujian enable row level security;
alter table public.ruang enable row level security;
alter table public.bank_soal enable row level security;
alter table public.sesi enable row level security;
alter table public.ujian enable row level security;
alter table public.peserta_ujian enable row level security;
alter table public.atur_ruang_sesi enable row level security;
alter table public.jawaban_siswa enable row level security;
alter table public.hasil_ujian enable row level security;
alter table public.pengumuman enable row level security;

-- helper: cek peran user
create or replace function public.is_admin()
returns boolean language sql stable as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin');
$$;

create or replace function public.is_guru()
returns boolean language sql stable as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'guru');
$$;

create or replace function public.is_siswa()
returns boolean language sql stable as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'siswa');
$$;

-- PROFILES: user bisa baca profile sendiri; admin baca semua
create policy "profiles_select_own" on public.profiles for select using (id = auth.uid());
create policy "profiles_select_admin" on public.profiles for select using (public.is_admin());
create policy "profiles_update_own" on public.profiles for update using (id = auth.uid());

-- DATA MASTER: admin penuh, yang lain hanya baca
create policy "master_admin_all" on public.sekolah for all using (public.is_admin()) with check (public.is_admin());
create policy "master_admin_all_2" on public.tahun_pelajaran for all using (public.is_admin()) with check (public.is_admin());
create policy "master_admin_all_3" on public.jurusan for all using (public.is_admin()) with check (public.is_admin());
create policy "master_read" on public.sekolah for select using (true);
create policy "master_read_2" on public.tahun_pelajaran for select using (true);
create policy "master_read_3" on public.jurusan for select using (true);

create policy "mapel_admin_all" on public.mata_pelajaran for all using (public.is_admin()) with check (public.is_admin());
create policy "mapel_read" on public.mata_pelajaran for select using (public.is_admin() or public.is_guru() or public.is_siswa());

create policy "kelas_admin_all" on public.kelas for all using (public.is_admin()) with check (public.is_admin());
create policy "kelas_read" on public.kelas for select using (public.is_admin() or public.is_guru() or public.is_siswa());

create policy "guru_admin_all" on public.guru for all using (public.is_admin()) with check (public.is_admin());
create policy "guru_read" on public.guru for select using (public.is_admin() or public.is_guru());

create policy "siswa_admin_all" on public.siswa for all using (public.is_admin()) with check (public.is_admin());
create policy "siswa_guru_read" on public.siswa for select using (public.is_admin() or public.is_guru());
create policy "siswa_self_read" on public.siswa for select using (auth.uid() = profile_id);

-- BANK SOAL: admin & guru penuh (guru hanya milik sendiri), siswa tidak
create policy "soal_admin_all" on public.bank_soal for all using (public.is_admin()) with check (public.is_admin());
create policy "soal_guru_all" on public.bank_soal for all using (public.is_guru() and guru_id = auth.uid()) with check (public.is_guru() and guru_id = auth.uid());
create policy "soal_guru_select_all" on public.bank_soal for select using (public.is_guru());

-- UJIAN: admin semua, guru ujiannya, siswa baca yang status aktif
create policy "ujian_admin_all" on public.ujian for all using (public.is_admin()) with check (public.is_admin());
create policy "ujian_guru_all" on public.ujian for all using (public.is_guru() and guru_id = auth.uid()) with check (public.is_guru() and guru_id = auth.uid());
create policy "ujian_siswa_read" on public.ujian for select using (public.is_siswa() and status = 'aktif');

-- SESI & RUANG
create policy "sesi_admin_guru" on public.sesi for all using (public.is_admin() or public.is_guru()) with check (public.is_admin() or public.is_guru());
create policy "sesi_read" on public.sesi for select using (true);
create policy "ruang_admin_guru" on public.ruang for all using (public.is_admin() or public.is_guru()) with check (public.is_admin() or public.is_guru());
create policy "ruang_read" on public.ruang for select using (true);

create policy "jujian_admin_guru" on public.jenis_ujian for all using (public.is_admin() or public.is_guru()) with check (public.is_admin() or public.is_guru());
create policy "jujian_read" on public.jenis_ujian for select using (true);

-- PESERTA UJIAN
create policy "peserta_admin_all" on public.peserta_ujian for all using (public.is_admin()) with check (public.is_admin());
create policy "peserta_guru_all" on public.peserta_ujian for all using (public.is_guru()) with check (public.is_guru());
create policy "peserta_siswa_self" on public.peserta_ujian for select using (auth.uid() = (select profile_id from public.siswa where siswa.id = peserta_ujian.siswa_id));

-- ATUR RUANG SESI
create policy "ars_admin" on public.atur_ruang_sesi for all using (public.is_admin()) with check (public.is_admin());
create policy "ars_guru" on public.atur_ruang_sesi for all using (public.is_guru()) with check (public.is_guru());

-- JAWABAN SISWA
create policy "jawaban_admin_all" on public.jawaban_siswa for all using (public.is_admin()) with check (public.is_admin());
create policy "jawaban_siswa_self" on public.jawaban_siswa for all using (
  auth.uid() = (select profile_id from public.siswa where siswa.id = (select siswa_id from public.peserta_ujian where peserta_ujian.id = jawaban_siswa.peserta_ujian_id))
) with check (
  auth.uid() = (select profile_id from public.siswa where siswa.id = (select siswa_id from public.peserta_ujian where peserta_ujian.id = jawaban_siswa.peserta_ujian_id))
);

-- HASIL UJIAN
create policy "hasil_admin" on public.hasil_ujian for all using (public.is_admin()) with check (public.is_admin());
create policy "hasil_guru" on public.hasil_ujian for all using (public.is_guru()) with check (public.is_guru());
create policy "hasil_siswa_self" on public.hasil_ujian for select using (
  auth.uid() = (select profile_id from public.siswa where siswa.id = (select siswa_id from public.peserta_ujian where peserta_ujian.id = hasil_ujian.peserta_ujian_id))
);

-- PENGUMUMAN
create policy "pengumuman_admin" on public.pengumuman for all using (public.is_admin()) with check (public.is_admin());
create policy "pengumuman_read" on public.pengumuman for select using (true);

-- ELEARNING (dasar)
create policy "materi_admin" on public.materi for all using (public.is_admin()) with check (public.is_admin());
create policy "materi_guru" on public.materi for all using (public.is_guru()) with check (public.is_guru());
create policy "materi_read" on public.materi for select using (true);

create policy "tugas_admin" on public.tugas for all using (public.is_admin()) with check (public.is_admin());
create policy "tugas_guru" on public.tugas for all using (public.is_guru()) with check (public.is_guru());
create policy "tugas_read" on public.tugas for select using (true);

create policy "kumpul_admin" on public.pengumpulan_tugas for all using (public.is_admin()) with check (public.is_admin());
create policy "kumpul_guru" on public.pengumpulan_tugas for all using (public.is_guru()) with check (public.is_guru());
create policy "kumpul_siswa" on public.pengumpulan_tugas for all using (public.is_siswa()) with check (public.is_siswa());

create policy "hadir_admin" on public.kehadiran for all using (public.is_admin() or public.is_guru()) with check (public.is_admin() or public.is_guru());

-- ============================================================
-- SEED DASAR
-- ============================================================
insert into public.sekolah (nama, npsn, alamat, kota) values ('SMA CBT Indonesia', '', '', '') on conflict do nothing;

insert into public.jenis_ujian (nama, keterangan) values ('Ulangan Harian', 'Penilaian harian'), ('Ujian Tengah Semester', 'UTS'), ('Ujian Akhir Semester', 'UAS'), ('Ujian Sekolah', 'US'), ('Try Out', 'Latihan ujian') on conflict do nothing;

insert into public.tahun_pelajaran (nama, semester, is_active) values ('2025/2026', 'Ganjil', true) on conflict do nothing;