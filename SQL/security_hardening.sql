-- Security hardening (overnight review, 2026-11-05).
--
-- Run AFTER every other file in SQL/ (it replaces functions from
-- reservations.sql, listed_huts.sql, external_reservations.sql and
-- beds_available.sql). Safe to run more than once: every step is
-- "drop ... if exists" / "create or replace" / guarded by a catalog check.
-- Paste the whole file into the Supabase SQL editor and run it.
--
-- Each part says what it fixes and how to check it afterwards. The test
-- queries are comments: run them by hand, as a signed-in user where it says
-- so (the SQL editor runs as postgres, which skips RLS; use the app, or
-- `set local role authenticated; set local request.jwt.claims = '{"sub":"<user uuid>"}';`
-- inside a transaction you roll back).
--
-- Section C at the bottom is commented out on purpose: legacy host / Posts
-- policies that look unused now. Read it, then decide.

begin;

-- ---------------------------------------------------------------------------
-- 1. Username -> email lookup is gone.
--
-- get_email_for_username() was SECURITY DEFINER and executable by anon: anyone
-- with the public anon key could turn any username into its account e-mail
-- (enumeration + phishing). Sign-in is by e-mail code now and the app no
-- longer calls it (grep "get_email_for_username" in Podz/: no hit).
--
-- Test: select proname from pg_proc where proname = 'get_email_for_username';
--       -> no row.
-- ---------------------------------------------------------------------------
drop function if exists public.get_email_for_username(text);


-- ---------------------------------------------------------------------------
-- 2. A reservation can only be cancelled after it's made.
--
-- The capacity and listed-hut triggers ran BEFORE INSERT only, and the update
-- policy let a user change their own row freely: book 1 guest, then update to
-- 40 guests, other dates, another pod_id (a listed hut), source = 'external',
-- or re-confirm a cancelled row, and no check ran again. Now:
--   - the update policy only matches a confirmed row of yours and only lets it
--     become cancelled;
--   - a BEFORE UPDATE trigger refuses any change other than
--     status 'confirmed' -> 'cancelled' (every other column is frozen), so it
--     holds even if another update policy is added later (e.g. the host one).
-- The service role / dashboard (postgres) can still edit rows by hand.
--
-- Test (as a signed-in user, from the app or with the role trick above):
--   update reservations set guests = 99 where id = '<your row>';
--     -> error "Only cancelling a reservation is allowed."
--   update reservations set status = 'confirmed' where id = '<a cancelled row>';
--     -> 0 rows (the policy no longer matches a cancelled row)
--   Cancel in the app (Profile > Reservations > Cancel) -> still works.
-- ---------------------------------------------------------------------------
create or replace function public.reservations_only_cancel()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    -- Hand edits from the dashboard or a server job are trusted.
    if current_user in ('postgres', 'supabase_admin', 'service_role')
       or coalesce(auth.role(), '') = 'service_role' then
        return new;
    end if;

    if old.status = 'confirmed' and new.status = 'cancelled'
       and new.id = old.id
       and new.pod_id = old.pod_id
       and new.user_id = old.user_id
       and new.check_in = old.check_in
       and new.check_out = old.check_out
       and new.guests = old.guests
       and new.source = old.source
       and new.created_at = old.created_at then
        return new;
    end if;

    raise exception 'Only cancelling a reservation is allowed.'
        using errcode = '42501';
end;
$$;

drop trigger if exists reservations_only_cancel on reservations;
create trigger reservations_only_cancel
    before update on reservations
    for each row execute function public.reservations_only_cancel();

drop policy if exists "Users can cancel their own reservations" on reservations;
create policy "Users can cancel their own reservations" on reservations
    for update
    using (user_id = auth.uid() and status = 'confirmed')
    with check (user_id = auth.uid() and status = 'cancelled');


-- ---------------------------------------------------------------------------
-- 3. The capacity check is safe when two people book at the same moment.
--
-- Under READ COMMITTED two inserts for the same pod could both read "18 of 20
-- booked", both pass and both commit (22 of 20). The function now takes a
-- transaction-scoped advisory lock per pod first, so bookings of one pod are
-- checked one after the other; the second one's count then includes the
-- first's committed row. Bookings of different pods don't wait for each other.
-- Based on the latest version (external_reservations.sql: an external stay
-- neither counts nor is checked). Also refuses a Podz booking that starts
-- before yesterday (one day of slack for time zones).
--
-- Test: two SQL editor tabs, each `begin; insert ... the last beds ...;`
--       without commit: the second waits; commit the first, the second fails
--       with "Not enough beds available".
-- ---------------------------------------------------------------------------
create or replace function public.enforce_reservation_capacity()
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

    -- One booking of this pod at a time (released at commit / rollback).
    perform pg_advisory_xact_lock(hashtext(new.pod_id::text));

    if new.check_in < current_date - 1 then
        raise exception 'A reservation can''t start in the past.';
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

drop trigger if exists reservations_enforce_capacity on reservations;
create trigger reservations_enforce_capacity
    before insert on reservations
    for each row execute function public.enforce_reservation_capacity();

-- Same function as listed_huts.sql / external_reservations.sql, with a fixed
-- search_path so a schema someone else can create objects in can't shadow
-- "pods".
create or replace function public.reject_reservation_on_listed_pod()
returns trigger
language plpgsql
set search_path = public
as $$
begin
    if new.source <> 'external'
       and exists (select 1 from pods where id = new.pod_id and listing_status = 'listed') then
        raise exception 'This hut is listed only: book through the hut.';
    end if;
    return new;
end;
$$;

drop trigger if exists reservations_reject_listed on reservations;
create trigger reservations_reject_listed
    before insert on reservations
    for each row execute function public.reject_reservation_on_listed_pod();


-- ---------------------------------------------------------------------------
-- 4. What an "external" row is allowed to be.
--
-- Anyone can insert source = 'external' directly (the app does it for "Did you
-- book it?"), which skips the capacity and listed-hut checks. That is by
-- design: it is a note in your own list, not a Podz booking. So it must never
-- be worth anything:
--   - it never counts against beds: the capacity trigger skips it, and
--     beds_available_now() below now only sums source = 'podz' (before, an
--     external note lowered the "N free now" every traveler sees);
--   - it never gets a trip pass: the app filters it out (TripPassStore) and
--     the generate-trip-pass edge function now requires source = 'podz' and
--     status = 'confirmed' (redeploy it, see the report);
--   - it can't be turned into a Podz booking later: part 2 freezes `source`;
--   - it is bounded: at most 20 guests and 30 nights (any row: 50 / 60).
-- Nothing else reads `source`. Constraints are NOT VALID so existing rows are
-- not re-checked; every new row is.
--
-- Test (as a user): insert an external row with guests = 25 -> check error.
--   select beds_available_now('<pod>') before / after adding an external
--   stay in the app -> unchanged.
-- ---------------------------------------------------------------------------
do $$
begin
    if not exists (select 1 from pg_constraint where conname = 'reservations_sane_size') then
        alter table reservations add constraint reservations_sane_size
            check (guests <= 50 and check_out - check_in <= 60) not valid;
    end if;
    if not exists (select 1 from pg_constraint where conname = 'reservations_external_bounds') then
        alter table reservations add constraint reservations_external_bounds
            check (source <> 'external' or (guests <= 20 and check_out - check_in <= 30)) not valid;
    end if;
end;
$$;

create or replace function public.beds_available_now(p_pod_id uuid)
returns int
language plpgsql
security definer
set search_path = public
stable
as $$
declare
    pod_capacity int;
    max_occupancy int;
begin
    select beds_total into pod_capacity from pods where id = p_pod_id;
    if pod_capacity is null then
        return 0;
    end if;

    select coalesce(max(nightly.guests), 0) into max_occupancy
    from (
        select coalesce(sum(r.guests), 0) as guests
        from generate_series(current_date, current_date + interval '29 days', interval '1 day') as d(night)
        left join reservations r
            on r.pod_id = p_pod_id
            and r.status = 'confirmed'
            and r.source = 'podz'
            and r.check_in <= d.night
            and r.check_out > d.night
        group by d.night
    ) nightly;

    return greatest(pod_capacity - max_occupancy, 0);
end;
$$;

revoke all on function public.beds_available_now(uuid) from public;
grant execute on function public.beds_available_now(uuid) to anon, authenticated;


-- ---------------------------------------------------------------------------
-- 5. Analytics tables can't be filled with junk.
--
-- app_events / app_diagnostics accept inserts from anon with check (true):
-- anyone with the anon key could send rows of any size (storage cost, a
-- dashboard full of noise). Size caps now bound every row. What the app sends
-- is far below them (event names are ~20 chars, props a few short strings,
-- a MetricKit report is cut at 200 KB on the phone); a batch the server
-- refuses is dropped by the app instead of retried forever.
--
-- Not done here, options if junk shows up: a per-install rate limit trigger
-- (count rows for install_id in the last minute, raise above ~120), only
-- accepting names from the app's list (`check (name in (...))`), or moving
-- inserts behind an edge function with its own rate limit.
--
-- Test: insert into app_events (... name = repeat('x', 100) ...) -> check error.
-- ---------------------------------------------------------------------------
do $$
begin
    if not exists (select 1 from pg_constraint where conname = 'app_events_size') then
        alter table public.app_events add constraint app_events_size check (
            char_length(name) between 1 and 64
            and pg_column_size(props) <= 2048
            and coalesce(char_length(app_version), 0) <= 32
            and coalesce(char_length(build), 0) <= 32
            and coalesce(char_length(os), 0) <= 64
            and coalesce(char_length(locale), 0) <= 32
            and occurred_at < now() + interval '1 day'
        ) not valid;
    end if;
    if not exists (select 1 from pg_constraint where conname = 'app_diagnostics_size') then
        alter table public.app_diagnostics add constraint app_diagnostics_size check (
            coalesce(char_length(summary), 0) <= 500
            and coalesce(octet_length(payload), 0) <= 262144
            and coalesce(char_length(app_version), 0) <= 32
            and coalesce(char_length(build), 0) <= 32
            and coalesce(char_length(os), 0) <= 128
        ) not valid;
    end if;
end;
$$;


-- ---------------------------------------------------------------------------
-- 6. The avatars bucket only takes small JPEGs.
--
-- The app now resizes a photo to 1024 px and refuses anything over 2 MB or not
-- a JPEG before uploading; the bucket should say the same so a client can't
-- put a 1 GB file or an HTML page under the public avatars URL. The per-user
-- folder policies on storage.objects for "avatars" are not in this repo:
-- check them in the dashboard (see the report).
--
-- Test: Storage > avatars > settings shows 2 MB and image/jpeg.
-- ---------------------------------------------------------------------------
update storage.buckets
set file_size_limit = 2097152,
    allowed_mime_types = array['image/jpeg']
where id = 'avatars';

commit;


-- ---------------------------------------------------------------------------
-- C. Legacy policies from the host side and Posts (both removed from the app).
--
-- NOT RUN: uncomment after checking nothing else uses them. The app no longer
-- writes to pods, pod_photos, pod_rooms, posts or the post-photos bucket.
--
-- The most important one is the first block. "Hosts can insert their own
-- pods" trusts profiles.is_host; if the profiles update policy lets a user
-- update their own row without restricting columns (likely, the app updates
-- its own profile), anyone can set is_host = true and then insert pods that
-- every traveler sees (with any phone / e-mail / website), update them and
-- delete them. Check with:
--   select polname, pg_get_expr(polqual, polrelid), pg_get_expr(polwithcheck, polrelid)
--   from pg_policy where polrelid = 'public.profiles'::regclass;
-- ---------------------------------------------------------------------------
-- drop policy if exists "Hosts can insert their own pods" on pods;
-- drop policy if exists "Hosts can update their own pods" on pods;
-- drop policy if exists "Hosts can delete their own pods" on pods;
-- drop policy if exists "Hosts can insert photos for their own pods" on pod_photos;
-- drop policy if exists "Hosts can delete their own pod photos" on pod_photos;
-- drop policy if exists "Hosts can delete their own pod rooms" on pod_rooms;
-- drop policy if exists "Hosts can view reservations on their own pods" on reservations;
-- drop policy if exists "Hosts can delete reservations on their own pods" on reservations;
--
-- Posts (posts_feed.sql). Rows stay; only the write paths close:
-- drop policy if exists "Author can insert own posts" on posts;
-- drop policy if exists "Author can insert own post photos" on post_photos;
-- drop policy if exists "Users can like visible posts" on post_likes;
-- drop policy if exists "Users can comment on visible posts" on post_comments;
-- drop policy if exists "Users can upload their own post photos" on storage.objects;
--
-- And, once nothing reads it, the column that made a user a host:
-- alter table profiles drop column if exists is_host;
