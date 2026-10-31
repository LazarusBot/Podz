-- What a night costs, shown on the pod detail ("45 € / night"). Null = not
-- known, and the app says the price is set by the hut. Paste into the
-- Supabase SQL editor and run once.

alter table pods add column if not exists price_per_night numeric(8, 2);
alter table pods add column if not exists price_currency text not null default 'EUR';

-- A partner hut's price, by hand for now:
--   update pods set price_per_night = 45 where name = 'Refuge du Goûter';
