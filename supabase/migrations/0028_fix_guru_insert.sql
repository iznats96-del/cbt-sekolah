-- ============================================================
-- CBT 0028: FIX GURU SOAL INSERTION PERMISSION
-- Allow guru to insert soal (auto-set guru_id from auth)
-- ============================================================

-- Drop existing strict policies
drop policy if exists "soal_guru_all" on public.bank_soal;
drop policy if exists "soal_guru_kunci_update" on public.bank_soal;
drop policy if exists "soal_guru_ujian_select" on public.bank_soal;
drop policy if exists "soal_admin_insert" on public.bank_soal;

-- New relaxed policy for guru insertion with default guru_id
create policy "soal_guru_insert" on public.bank_soal 
for insert to authenticated
with check (public.is_guru());

-- Auto-default guru_id using trigger or defaul
alter table public.bank_soal 
add constraint if not exists bank_soal_guru_id_default
check (guru_id is not null);

-- Add trigger function to auto-set guru_id
create or replace function public.set_guru_id_on_insert()
returns trigger language plpgsql security definer as $$
begin
  if new.guru_id is null then
    new.guru_id := auth.uid();
  end if;
  return new;
end;
$$;

-- Create trigger to auto-populate guru_id
drop trigger if exists trg_set_guru_id on public.bank_soal;
create trigger trg_set_guru_id
before insert on public.bank_soal
for each row execute procedure public.set_guru_id_on_insert();

-- Revoke all privileges from anon/public
revoke all on public.bank_soal from anon;
grant select, insert on public.bank_soal to authenticated;
grant update on public.bank_soal to authenticated where (public.is_guru() and guru_id = auth.uid()) or (public.is_admin());

-- Grant execute on trigger function
grant execute on function public.set_guru_id_on_insert() to authenticated;
