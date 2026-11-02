-- Hand-picked huts: shown first on Home ("Hand-picked") and ranked above the
-- rest in the shelves and in search. Paste into the Supabase SQL editor once,
-- then mark huts with:
--   update pods set featured = true where id in ('...', '...');
-- (tools/content_report.py writes a first list of the best-documented French
-- huts: tools/out/featured_huts.sql.)

alter table pods add column if not exists featured boolean not null default false;
