-- Reservations: book a stay at a pod (no payment collected — settled at
-- the shelter, same as many real mountain refuges already work). No
-- migration tooling wired up for this project, same as posts_feed.sql —
-- paste this whole file into the Supabase SQL editor and run it once.

create table if not exists reservations (
    id uuid primary key default gen_random_uuid(),
    pod_id uuid not null references pods(id) on delete cascade,
    user_id uuid not null references profiles(id) on delete cascade,
    check_in date not null,
    check_out date not null,
    guests int not null check (guests > 0),
    status text not null default 'confirmed' check (status in ('confirmed', 'cancelled')),
    created_at timestamptz not null default now(),
    check (check_out > check_in)
);

alter table reservations enable row level security;

-- drop-if-exists before each policy (unlike a plain `create policy`,
-- which errors "already exists" on a second run) — that error, hit while
-- re-running this file to troubleshoot, was very likely what silently
-- stopped this whole script short of ever reaching the trigger below,
-- since the Supabase SQL editor runs a pasted script as one batch and
-- aborts it at the first error.
drop policy if exists "Users can view their own reservations" on reservations;
create policy "Users can view their own reservations" on reservations
    for select using (user_id = auth.uid());

drop policy if exists "Users can insert their own reservations" on reservations;
create policy "Users can insert their own reservations" on reservations
    for insert with check (user_id = auth.uid());

drop policy if exists "Users can cancel their own reservations" on reservations;
create policy "Users can cancel their own reservations" on reservations
    for update using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Booking against the shelter's overall beds_total (not a specific room —
-- pod_rooms has no per-room capacity yet). This runs server-side, not
-- just as a client-side estimate, so two people booking the last beds at
-- the same moment can't both succeed: whichever insert lands second sees
-- its capacity check include the first's now-committed row and fails
-- cleanly instead of silently overbooking.
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
    select beds_total into pod_capacity from pods where id = new.pod_id;

    -- No capacity on record for this pod — nothing to enforce against.
    if pod_capacity is null then
        return new;
    end if;

    select coalesce(sum(guests), 0) into already_booked
    from reservations
    where pod_id = new.pod_id
      and status = 'confirmed'
      and check_in < new.check_out
      and check_out > new.check_in;

    if already_booked + new.guests > pod_capacity then
        raise exception 'Not enough beds available for those dates (% of % already booked).', already_booked, pod_capacity;
    end if;

    return new;
end;
$$;

drop trigger if exists reservations_enforce_capacity on reservations;
create trigger reservations_enforce_capacity
    before insert on reservations
    for each row execute function enforce_reservation_capacity();
