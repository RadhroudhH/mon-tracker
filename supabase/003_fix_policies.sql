-- =====================================================================
-- Carnet: SECURITY FIX (2026-11-08 incident)
--
-- Problem: the tables still had older, permissive policies (created when
-- the project was first set up, e.g. "allow all"). Postgres combines
-- policies with OR, so any signed-in user could read and delete every
-- row, despite the "own rows" policy added by 001_multi_user.sql.
--
-- This script removes EVERY policy on Carnet's tables and recreates only
-- the strict "own rows" one. Run it once in Supabase → SQL Editor.
-- One atomic block: if anything fails, nothing changes.
-- =====================================================================

do $fix$
declare
  t text;
  p record;
begin
  foreach t in array array['depenses', 'revenus', 'carte', 'taux', 'cards'] loop
    continue when to_regclass('public.' || t) is null;  -- cards may not exist yet

    -- 1. drop ALL existing policies on the table, whatever their name
    for p in select policyname from pg_policies where schemaname = 'public' and tablename = t loop
      raise notice 'dropping policy "%" on %', p.policyname, t;
      execute format('drop policy %I on public.%I', p.policyname, t);
    end loop;

    -- 2. RLS on, and only the strict per-user policy
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy "own rows" on public.%I for all to authenticated
         using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)', t);

    -- 3. logged-out visitors get nothing
    execute format('revoke all on public.%I from anon', t);
  end loop;
end
$fix$;

-- Check: every Carnet table must show exactly ONE policy, "own rows"
select tablename, policyname, roles, cmd, qual
from pg_policies
where schemaname = 'public' and tablename in ('depenses', 'revenus', 'carte', 'taux', 'cards')
order by tablename;
