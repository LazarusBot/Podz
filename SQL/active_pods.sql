-- Which pods the app loads. Only active pods are fetched, so a smaller launch
-- area means a lighter, faster app. Nothing is deleted: turning a country back
-- on is one update. Paste into the Supabase SQL editor and run once, BEFORE
-- installing the app version that filters on it.

alter table pods add column if not exists is_active boolean not null default true;

-- For now: France only.
update pods set is_active = (country = 'France');

-- Later, to open another country (or everything):
--   update pods set is_active = true where country = 'Italy';
--   update pods set is_active = true;
