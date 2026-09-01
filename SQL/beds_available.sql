-- Live "beds available" for a pod — depends on reservations.sql already
-- being run (this reads that table). Paste into the Supabase SQL editor
-- and run once; safe to re-run (create or replace) if you already have
-- an earlier version of this function.
--
-- `reservations` RLS only lets a user see their *own* rows (see
-- reservations.sql), so a plain client-side query can never compute real
-- availability across every guest's bookings — it would only ever see the
-- current user's own reservations. This RPC runs with elevated privilege
-- to sum every confirmed reservation for the pod, but only ever returns
-- one aggregate number, never the underlying rows — nobody's booking
-- details leak through it.
--
-- Checks the *busiest* night over the next 30 days, not just today —
-- a reservation almost never starts today (ReservationSheet defaults to
-- tomorrow), so a strict "today" check barely ever moved regardless of
-- what got booked. This reflects any near-term reservation instead.
create or replace function beds_available_now(p_pod_id uuid)
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
            and r.check_in <= d.night
            and r.check_out > d.night
        group by d.night
    ) nightly;

    return greatest(pod_capacity - max_occupancy, 0);
end;
$$;

revoke all on function beds_available_now(uuid) from public;
grant execute on function beds_available_now(uuid) to anon, authenticated;
