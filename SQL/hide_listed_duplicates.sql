-- A partner hut that is also in the OpenStreetMap import would show twice: the
-- bookable partner and a listed copy. This hides the listed copy (is_active =
-- false, nothing is deleted). Each pair was checked by name and by distance
-- (all within 1.4 km). Run after SQL/active_pods.sql.

update pods set is_active = false where id in (
    '372a9017-c085-4048-9129-6f9518700a86',  -- Kamniška koča na Kamniškem sedlu
    '1cd85e84-6664-4be7-ac94-cca6d2558700',  -- Santnerpasshütte - Rifugio Passo Santner
    '0f1a1893-22c7-4824-ad0f-44869d10bde5',  -- Bivak pod Skuto na Malih podih
    'a7c01b39-f91e-46fd-9ffc-e1980c89f518',  -- Refuge d'Argentière
    'b4b88e77-d1d7-40cf-aa73-425d7488b083'   -- Refuge du Goûter
) and listing_status = 'listed';

-- Check: this should now list only the partners.
--   select name, listing_status, is_active from pods
--   where name ilike '%Gouter%' or name ilike '%Goûter%' or name ilike '%Argenti%'
--      or name ilike '%Santner%' or name ilike '%Skuto%' or name ilike '%Kamni%';
