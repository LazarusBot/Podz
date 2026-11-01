-- A stay booked through the hut itself (a listed hut takes bookings by phone,
-- email or its website), which the traveler then adds to their list in the app
-- ("Did you book it?" -> Lenny asks the dates). Such a row has source =
-- 'external': it isn't a Podz booking, so it skips the listed-hut guard and the
-- bed counts, and it has no trip pass. Paste into the Supabase SQL editor and
-- run once, after SQL/listed_huts.sql.

alter table reservations add column if not exists source text not null default 'podz'
    check (source in ('podz', 'external'));

-- Only a Podz booking is refused on a listed hut.
create or replace function reject_reservation_on_listed_pod()
returns trigger as $$
begin
    if new.source <> 'external'
       and exists (select 1 from pods where id = new.pod_id and listing_status = 'listed') then
        raise exception 'This hut is listed only: book through the hut.';
    end if;
    return new;
end;
$$ language plpgsql;

-- Capacity is about Podz bookings only: an external stay neither counts nor is
-- checked.
create or replace function enforce_reservation_capacity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    pod_capacity int;
    already_booked int;
begin
    if new.source = 'external' then
        return new;
    end if;

    select beds_total into pod_capacity from pods where id = new.pod_id;

    if pod_capacity is null then
        return new;
    end if;

    select coalesce(sum(guests), 0) into already_booked
    from reservations
    where pod_id = new.pod_id
      and status = 'confirmed'
      and source = 'podz'
      and check_in < new.check_out
      and check_out > new.check_in;

    if already_booked + new.guests > pod_capacity then
        raise exception 'Not enough beds available for those dates (% of % already booked).', already_booked, pod_capacity;
    end if;

    return new;
end;
$$;
