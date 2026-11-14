-- 0044: soal per-kelas — tambah kolom kelas_id di bank_soal
-- NULL = soal global (semua kelas), terisi = khusus kelas itu saja.
begin;

alter table public.bank_soal
  add column if not exists kelas_id uuid references public.kelas(id) on delete cascade;

comment on column public.bank_soal.kelas_id is 'NULL=global semua kelas; terisi=khusus kelas tersebut';

-- RLS: policy admin/guru ALL untuk bank_soal harus ikut kelas? (sudah ada bank_soal policy)
-- tidak perlu diganti — akses admin/guru tetap full bank_soal.

commit;
