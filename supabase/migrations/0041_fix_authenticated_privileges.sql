-- ============================================================
-- CBT 0041: sinkronkan privilege tabel untuk client authenticated
--
-- Supabase memisahkan privilege SQL dari RLS policy. Jika privilege
-- tabel pernah diubah, admin/guru bisa mendapat 42501 walaupun policy
-- yang benar sudah ada. GRANT ini tidak membuka data: RLS tetap aktif.
-- ============================================================

grant usage on schema public to authenticated;

grant select, insert, update, delete on
  public.profiles,
  public.sekolah,
  public.tahun_pelajaran,
  public.jurusan,
  public.mata_pelajaran,
  public.kelas,
  public.guru,
  public.siswa,
  public.materi,
  public.tugas,
  public.pengumpulan_tugas,
  public.kehadiran,
  public.jenis_ujian,
  public.ruang,
  public.sesi,
  public.bank_soal,
  public.ujian,
  public.ujian_kelas,
  public.jadwal_mapel,
  public.peserta_ujian,
  public.atur_ruang_sesi,
  public.jawaban_siswa,
  public.hasil_ujian,
  public.pengumuman
to authenticated;

grant usage, select on all sequences in schema public to authenticated;

-- Pastikan RPC yang dipanggil layar admin/guru tetap dapat dieksekusi.
grant execute on all functions in schema public to authenticated;
