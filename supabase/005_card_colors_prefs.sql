-- =====================================================================
-- Carnet: card colors + per-user preferences (dashboard layout, theme)
-- Run ONCE in Supabase → SQL Editor, after 002_cards.sql. Nothing to edit.
-- One atomic block: if anything fails, nothing changes.
-- =====================================================================

do $migration$
declare
  pol record;
begin
  -- 1. Each card can have its own color (picked from a fixed palette in the app)
  alter table public.cards add column if not exists color text
    check (color is null or color ~ '^#[0-9A-Fa-f]{6}$');

  -- 2. One preferences row per user: dashboard order, hidden sections, theme, category colors
  create table if not exists public.prefs (
    user_id    uuid primary key default auth.uid() references auth.users (id) on delete cascade,
    data       jsonb not null default '{}'::jsonb check (pg_column_size(data) < 20000),
    updated_at timestamptz not null default now()
  );

  -- Strict per-user access only: drop ANY policy, then add "own rows"
  for pol in select policyname from pg_policies where schemaname = 'public' and tablename = 'prefs' loop
    execute format('drop policy %I on public.prefs', pol.policyname);
  end loop;
  alter table public.prefs enable row level security;
  create policy "own rows" on public.prefs for all to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
  revoke all on public.prefs from anon;
end
$migration$;

-- Check: one policy on prefs, and the new cards.color column
select tablename, policyname from pg_policies where schemaname = 'public' and tablename = 'prefs';
select column_name from information_schema.columns where table_schema = 'public' and table_name = 'cards' and column_name = 'color';
