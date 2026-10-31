-- What a hut has on site (meals, showers, drinking water...), shown in the pod
-- detail. A list of short labels; null = nobody has said (the app then tells
-- the traveler to ask the hut). Paste into the Supabase SQL editor and run once.

alter table pods add column if not exists facilities text[];

-- A partner hut's facilities are set by its host, or by hand for now:
--   update pods set facilities = array['Meals','Showers','Drinking water'] where name = 'My hut';
