-- Listed huts: shelters that are in the app as information only ("book through
-- the hut"), next to partner huts that can be booked in the app. Existing pods
-- stay partners (the default), so nothing changes for them.
-- Paste this whole file into the Supabase SQL editor and run it once.

alter table pods add column if not exists listing_status text not null default 'partner'
    check (listing_status in ('partner', 'listed'));

-- How to book a listed hut: whichever of these the hut has.
alter table pods add column if not exists phone text;
alter table pods add column if not exists email text;
alter table pods add column if not exists website text;
alter table pods add column if not exists booking_url text;
alter table pods add column if not exists opening_hours text;

-- Where a listed hut's information comes from, to update it and to credit it
-- ("osm" = OpenStreetMap contributors, ODbL: the app shows the credit).
alter table pods add column if not exists source text;
alter table pods add column if not exists source_id text;

-- One row per source object, so the import can be run again safely.
create unique index if not exists pods_source_unique
    on pods (source, source_id) where source is not null;

-- Only a partner can be reserved: the capacity trigger and the app must not
-- accept a reservation on a listed hut.
create or replace function reject_reservation_on_listed_pod()
returns trigger as $$
begin
    if exists (select 1 from pods where id = new.pod_id and listing_status = 'listed') then
        raise exception 'This hut is listed only: book through the hut.';
    end if;
    return new;
end;
$$ language plpgsql;

drop trigger if exists reservations_reject_listed on reservations;
create trigger reservations_reject_listed
    before insert on reservations
    for each row execute function reject_reservation_on_listed_pod();
