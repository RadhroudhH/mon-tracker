# Multi-user accounts: go-live guide

> **Incident, 2026-11-08.** An invited user could see and erase the owner's data.
> Cause: old permissive policies (from the original Supabase setup) were still on the tables. Postgres ORs policies together, so those old rules overrode the new "own rows" one. `001` only dropped its own policy name.
> Fix: run `supabase/003_fix_policies.sql`, which drops every policy and recreates only "own rows". Then run the private restore script `backups/RESTORE-2026-11-08.sql`, which is never committed.
> The app now also filters every read and delete by `user_id` as a second safety net.

The code is ready: the sign-in screen, per-user data, account settings and `privacy.html`.
The database part is `supabase/001_multi_user.sql`. Follow these steps **in order**.

## Why this matters

Until step 4 runs, the database has **no Row Level Security**. Anyone who reads the page source gets the public key, and with it they can read, edit or delete all the rows. This was checked with `curl` on 2026-11-08.
The PIN never protected the database. It only hid the screen.

## Steps

1. **Back up.** Export to Excel from the current site. JSON copies from 2026-11-08 are also in `backups/`, which git ignores.

2. **Configure Supabase Auth** in Dashboard → Authentication:
   - **URL Configuration** → Site URL: the live address, e.g. `https://radhroudhh.github.io/mon-tracker/`. Add the same address under *Redirect URLs*.
   - **Sign In / Providers** → Email: enabled, *Confirm email* on, and *Allow new users to sign up* **on for now**.

3. **Deploy the new code** by committing and pushing to `main`. GitHub Pages updates in about a minute.
   Open the site, then **Create an account** with your email and confirm it from your inbox.
   You will still see all your data. That is expected until step 4.

4. **Run the migration.** In Dashboard → SQL Editor, paste `supabase/001_multi_user.sql`, replace `YOUR-EMAIL@example.com` with your email, and click Run.
   The script runs as one transaction: if anything fails, nothing changes.
   It gives every existing row to your account, turns on RLS, blocks logged-out access, and adds the `delete_my_account()` function.

5. **Make it invite-only.** Go back to Sign In / Providers and turn *Allow new users to sign up* **off**.
   To add someone, use Authentication → Users → *Invite user*. They get an email, land on the site, and choose a password.

6. **Check:**
   - Signed in as you, all your entries are there (167 expenses, 43 income entries and 53 card operations as of 2026-11-08, plus anything added since).
   - Invite a second email, or use a test address: that account sees an empty tracker.
   - Logged out, `curl "https://sopwocrilelcxitpqvem.supabase.co/rest/v1/depenses?select=*" -H "apikey: <key>"` returns `[]` or a permission error.

7. **Fill in `privacy.html`**: your contact email and your Supabase region (Project Settings → General). The site works before you do this, but the policy is incomplete until then.

Between step 3 and step 4 the site works the same as before. Only the PIN is gone. Keep that window short.

8. **Custom cards.** Run `supabase/002_cards.sql` in the SQL Editor. There is nothing to edit.
   It creates the `cards` table, so each user gets their own list and new users start with none.
   It also recreates your two cards (Zitouna Technologique and La Poste D17) under the same ids, so your card operations stay attached.
   Until you run it, the site falls back to your two existing cards, but new cards cannot be saved.

9. **Custom categories and goals.** Run `supabase/004_categories_goals.sql`. There is nothing to edit.
   It creates the `categories` and `goals` tables with strict per-user policies, and recreates your "Six-month goal" (1,200 DT of savings).
   Until you run it, the Goals section and the "+ New" category button stay hidden.

## Legal checklist (not legal advice)

**Tunisia, Organic Law 2004-63 (INPDP).** Processing personal data needs a **prior declaration to the INPDP** (Decree 2007-3004). Supabase stores data outside Tunisia, and **transfers abroad need INPDP authorization**. Do this before opening sign-ups to the public.

**EU users (GDPR).** GDPR applies whatever the size of the app. What it requires is now covered:
- a privacy policy reachable before sign-up: `privacy.html` plus the consent checkbox
- export: Excel and JSON
- real deletion: the "Delete my account" button
- security: RLS, hashed passwords and HTTPS
- no tracking cookies, so no cookie banner is needed

**Recommended approach.** Stay **invite-only** for yourself and people you know. File the INPDP declaration and get a quick review by a Tunisian lawyer before opening public sign-up.

Sources: Supabase RLS patterns (makerkit.dev/blog/tutorials/supabase-rls-best-practices), DLA Piper Tunisia overview (dlapiperdataprotection.com/?t=law&c=TN), Decree 2007-3004 (knobbe.com), BK Associés practical guide (bkassocies.tn), GDPR developer checklist (dev.to).
