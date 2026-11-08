-- =====================================================================
-- Carnet: user-defined cards
-- Run ONCE in Supabase → SQL Editor, after 001_multi_user.sql.
-- Nothing to edit: just run it. One atomic block: if anything fails,
-- nothing changes.
--
-- Each user now has their own list of cards (empty for new users).
-- Your two existing cards ("techno" and "d17") are created for you, with
-- the same ids your card operations already point to, so no operation
-- moves.
-- =====================================================================

do $migration$
begin
  create table if not exists public.cards (
    id         text primary key,
    user_id    uuid not null default auth.uid() references auth.users (id) on delete cascade,
    name       text not null check (char_length(name) between 1 and 60),
    style      text not null default 'default' check (style in ('default', 'd17', 'techno', 'custom')),
    image      text check (image is null or char_length(image) <= 400000),  -- uploaded image, resized in the browser (data URL)
    fx         boolean not null default false,                               -- can pay in USD / EUR
    fx_limit   numeric check (fx_limit is null or fx_limit > 0),             -- optional annual foreign-currency limit (DT)
    created_at timestamptz not null default now()
  );

  create index if not exists cards_user_id_idx on public.cards (user_id);

  alter table public.cards enable row level security;
  drop policy if exists "own rows" on public.cards;
  create policy "own rows" on public.cards for all to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
  revoke all on public.cards from anon;

  -- Recreate the existing owner's two cards (only for users who already have operations on them)
  insert into public.cards (id, user_id, name, style, fx, fx_limit, created_at)
  select distinct on (c.user_id) 'techno', c.user_id, 'Zitouna Technologique', 'techno', true, 1000, now()
  from public.carte c where c.card = 'techno'
  on conflict (id) do nothing;

  insert into public.cards (id, user_id, name, style, fx, fx_limit, created_at)
  select distinct on (c.user_id) 'd17', c.user_id, 'La Poste D17', 'd17', false, null, now() + interval '1 second'
  from public.carte c where c.card = 'd17'
  on conflict (id) do nothing;
end
$migration$;

-- Check: should list your two cards
select id, name, style, fx, fx_limit from public.cards order by created_at;
