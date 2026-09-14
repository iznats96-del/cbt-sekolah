-- 0005: tambah kolom updated_at untuk tabel yg pakai trigger tg_updated_at
alter table public.tahun_pelajaran add column if not exists updated_at timestamptz not null default now();
alter table public.siswa           add column if not exists updated_at timestamptz not null default now();
alter table public.guru            add column if not exists updated_at timestamptz not null default now();
alter table public.bank_soal       add column if not exists updated_at timestamptz not null default now();
alter table public.peserta_ujian   add column if not exists updated_at timestamptz not null default now();