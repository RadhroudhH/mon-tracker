-- =====================================================================
-- Carnet: weekly backup slot
-- Run ONCE in Supabase → SQL Editor. Nothing to edit.
-- One row per user: a single backup slot that the weekly backup overwrites.
-- "Erase all my entries" never touches it; deleting the account removes it.
-- =====================================================================

do $migration$
begin
  create table if not exists public.backups (
    user_id   uuid primary key default auth.uid() references auth.users (id) on delete cascade,
    data      jsonb,                                  -- the snapshot (null once the user deletes it)
    taken_at  timestamptz,                            -- when the snapshot was made
    weekly    boolean not null default false,         -- weekly backups switched on
    anchor_at timestamptz,                            -- the day weekly backups were switched on (start of the 7-day cycle)
    updated_at timestamptz not null default now()
  );

  alter table public.backups enable row level security;
  drop policy if exists "own rows" on public.backups;  -- new table: no other policies exist
  create policy "own rows" on public.backups for all to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
  revoke all on public.backups from anon;
end
$migration$;

-- Check: should list exactly one policy, "own rows"
select policyname from pg_policies where schemaname = 'public' and tablename = 'backups';
