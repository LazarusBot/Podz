-- Lets a host see the reservations made against their own pods — not
-- just their own bookings elsewhere. reservations.sql's own select
-- policy only ever exposed a guest's own rows (`user_id = auth.uid()`);
-- host_pod_management.sql added a host's *delete* rights over these same
-- rows but never a select policy, so a host querying reservations for a
-- pod they own (but didn't book themselves) was still blocked by RLS.
-- No migration tooling wired up for this project, same as every other
-- file in SQL/ — paste this whole file into the Supabase SQL editor and
-- run it once.

drop policy if exists "Hosts can view reservations on their own pods" on reservations;
create policy "Hosts can view reservations on their own pods" on reservations
    for select using (
        exists (select 1 from pods where pods.id = reservations.pod_id and pods.host_id = auth.uid())
    );
