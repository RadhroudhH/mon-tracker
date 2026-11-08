-- =====================================================================
-- Carnet: multi-user migration
-- Run ONCE in Supabase → SQL Editor, AFTER you created your account
-- through the new sign-in screen (and confirmed your email).
--
-- 1. Put the email you signed up with on the "owner_email" line below.
-- 2. Run the whole file.
--
-- Everything is inside ONE "do" block, so Postgres runs it as a single
-- atomic statement: if anything fails, nothing changes.
-- =====================================================================

do $migration$
declare
  owner_email text := 'YOUR-EMAIL@example.com';   -- <<< your email here
  owner_id uuid;
begin
  -- ---------- 0. Find the owner of the existing data ----------
  select id into owner_id from auth.users where lower(email) = lower(trim(owner_email));
  if owner_id is null then
    raise exception 'No account found for %: sign up in the app first (and confirm the email)', owner_email;
  end if;

  -- ---------- 1. Add user_id to every table ----------
  alter table public.depenses add column if not exists user_id uuid references auth.users (id) on delete cascade;
  alter table public.revenus  add column if not exists user_id uuid references auth.users (id) on delete cascade;
  alter table public.carte    add column if not exists user_id uuid references auth.users (id) on delete cascade;
  alter table public.taux     add column if not exists user_id uuid references auth.users (id) on delete cascade;

  -- ---------- 2. Give all existing rows to you ----------
  update public.depenses set user_id = owner_id where user_id is null;
  update public.revenus  set user_id = owner_id where user_id is null;
  update public.carte    set user_id = owner_id where user_id is null;
  update public.taux     set user_id = owner_id where user_id is null;

  -- New rows automatically belong to whoever inserts them
  alter table public.depenses alter column user_id set default auth.uid();
  alter table public.revenus  alter column user_id set default auth.uid();
  alter table public.carte    alter column user_id set default auth.uid();
  alter table public.taux     alter column user_id set default auth.uid();

  alter table public.depenses alter column user_id set not null;
  alter table public.revenus  alter column user_id set not null;
  alter table public.carte    alter column user_id set not null;
  alter table public.taux     alter column user_id set not null;

  create index if not exists depenses_user_id_idx on public.depenses (user_id);
  create index if not exists revenus_user_id_idx  on public.revenus (user_id);
  create index if not exists carte_user_id_idx    on public.carte (user_id);

  -- ---------- 3. Exchange rates: one row per user ----------
  -- (the old single row "id = 1" is kept and now belongs to you)
  alter table public.taux drop constraint if exists taux_pkey;
  alter table public.taux alter column id drop not null;
  alter table public.taux add primary key (user_id);

  -- ---------- 4. Row Level Security: each user only sees their own rows ----------
  alter table public.depenses enable row level security;
  alter table public.revenus  enable row level security;
  alter table public.carte    enable row level security;
  alter table public.taux     enable row level security;

  drop policy if exists "own rows" on public.depenses;
  drop policy if exists "own rows" on public.revenus;
  drop policy if exists "own rows" on public.carte;
  drop policy if exists "own rows" on public.taux;

  create policy "own rows" on public.depenses for all to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
  create policy "own rows" on public.revenus for all to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
  create policy "own rows" on public.carte for all to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
  create policy "own rows" on public.taux for all to authenticated
    using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

  -- Logged-out visitors get nothing at all
  revoke all on public.depenses, public.revenus, public.carte, public.taux from anon;

  -- ---------- 5. "Delete my account" (called from Settings) ----------
  -- Deleting the auth user cascades to all of that user's rows.
  create or replace function public.delete_my_account()
  returns void
  language plpgsql
  security definer
  set search_path = ''
  as $fn$
  begin
    if auth.uid() is null then
      raise exception 'not signed in';
    end if;
    delete from auth.users where id = auth.uid();
  end;
  $fn$;

  revoke all on function public.delete_my_account() from public, anon;
  grant execute on function public.delete_my_account() to authenticated;

  raise notice 'Migration done. Rows now owned by %: depenses=%, revenus=%, carte=%',
    owner_email,
    (select count(*) from public.depenses where user_id = owner_id),
    (select count(*) from public.revenus  where user_id = owner_id),
    (select count(*) from public.carte    where user_id = owner_id);
end
$migration$;

-- ---------- Check (shows your row counts) ----------
select
  (select count(*) from public.depenses) as depenses,
  (select count(*) from public.revenus)  as revenus,
  (select count(*) from public.carte)    as carte,
  (select relrowsecurity from pg_class where oid = 'public.depenses'::regclass) as rls_on;
-- Expected: 167 / 43 / 53 (or more if you added entries since 2026-11-08), rls_on = true
