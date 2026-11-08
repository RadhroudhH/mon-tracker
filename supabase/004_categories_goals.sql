-- =====================================================================
-- Carnet: custom categories + savings goals
-- Run ONCE in Supabase → SQL Editor. Nothing to edit.
-- One atomic block: if anything fails, nothing changes.
--
-- - categories: each user's own expense categories (the built-in ones
--   Food, Delivery, Transport, Other, Savings, Offset stay available).
-- - goals: any number of goals per user, each with a target amount, an
--   optional date, and what it tracks (savings, total balance, or a card).
-- Your existing "Six-month goal" (1,200 DT of savings) is recreated for you.
-- =====================================================================

do $migration$
declare
  t text;
  pol record;
  owner uuid;
begin
  create table if not exists public.categories (
    id         text primary key,
    user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
    name       text not null check (char_length(name) between 1 and 30),
    glyph      text not null default '•' check (char_length(glyph) between 1 and 8),
    color      text not null default '#C4A85C' check (color ~ '^#[0-9A-Fa-f]{6}$'),
    created_at timestamptz not null default now()
  );

  create table if not exists public.goals (
    id          text primary key,
    user_id     uuid not null default auth.uid() references auth.users (id) on delete cascade,
    name        text not null check (char_length(name) between 1 and 60),
    target      numeric not null check (target > 0),
    target_date date,
    scope       text not null default 'savings' check (scope in ('savings', 'total', 'card')),
    card_id     text,
    created_at  timestamptz not null default now(),
    check (scope <> 'card' or card_id is not null)
  );

  create index if not exists categories_user_id_idx on public.categories (user_id);
  create index if not exists goals_user_id_idx on public.goals (user_id);

  -- Strict per-user access only: drop ANY policy, then add "own rows"
  foreach t in array array['categories', 'goals'] loop
    for pol in select policyname from pg_policies where schemaname = 'public' and tablename = t loop
      execute format('drop policy %I on public.%I', pol.policyname, t);
    end loop;
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy "own rows" on public.%I for all to authenticated
         using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)', t);
    execute format('revoke all on public.%I from anon', t);
  end loop;

  -- Recreate the original owner's goal (owner = author of the very first entry, "d0")
  select user_id into owner from public.depenses where id = 'd0';
  if owner is not null then
    insert into public.goals (id, user_id, name, target, target_date, scope, created_at)
    values ('g-legacy', owner, 'Six-month goal', 1200, null, 'savings', now())
    on conflict (id) do nothing;
  end if;
end
$migration$;

-- Check: both tables have exactly one policy, and your goal exists
select tablename, policyname from pg_policies where schemaname = 'public' and tablename in ('categories', 'goals');
select id, name, target, scope from public.goals;
