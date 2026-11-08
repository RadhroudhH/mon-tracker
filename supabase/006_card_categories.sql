-- =====================================================================
-- Carnet: categories on card operations
-- Run ONCE in Supabase → SQL Editor. Nothing to edit.
-- Card purchases can now have a category (Food, Transport, your own…),
-- like cash expenses. Existing card purchases stay uncategorized and are
-- counted as "Other" in the charts until you edit them.
-- =====================================================================

alter table public.carte add column if not exists category text
  check (category is null or char_length(category) between 1 and 64);

-- Check: should return one row, "category"
select column_name from information_schema.columns
where table_schema = 'public' and table_name = 'carte' and column_name = 'category';
