-- Lets a host delete their own pods (and everything under them).
-- SQL/host_accounts.sql only ever added an INSERT policy for pods — this
-- adds the DELETE policies PodsStore.deletePod needs on pods,
-- pod_photos, pod_rooms, and reservations. No migration tooling wired up
-- for this project, same as every other file in SQL/ — paste this whole
-- file into the Supabase SQL editor and run it once.

-- pod_photos/pod_rooms predate SQL/ entirely, so their current RLS state
-- isn't tracked anywhere. Enabling it here is idempotent if it's already
-- on. If it was actually off, PodsStore.createPod's own photo upload
-- (added this session) was relying on that — the insert policy below
-- covers it so turning RLS on here doesn't silently break pod creation
-- the moment this file runs.
alter table pod_photos enable row level security;
alter table pod_rooms enable row level security;

drop policy if exists "Anyone can view pod photos" on pod_photos;
create policy "Anyone can view pod photos" on pod_photos
    for select using (true);

drop policy if exists "Hosts can insert photos for their own pods" on pod_photos;
create policy "Hosts can insert photos for their own pods" on pod_photos
    for insert with check (
        exists (select 1 from pods where pods.id = pod_photos.pod_id and pods.host_id = auth.uid())
    );

drop policy if exists "Hosts can delete their own pod photos" on pod_photos;
create policy "Hosts can delete their own pod photos" on pod_photos
    for delete using (
        exists (select 1 from pods where pods.id = pod_photos.pod_id and pods.host_id = auth.uid())
    );

-- No client-side insert flow for pod_rooms yet, so no insert policy —
-- select/delete only, matching what actually happens today (rooms get
-- seeded some other way, outside RLS's reach either way).
drop policy if exists "Anyone can view pod rooms" on pod_rooms;
create policy "Anyone can view pod rooms" on pod_rooms
    for select using (true);

drop policy if exists "Hosts can delete their own pod rooms" on pod_rooms;
create policy "Hosts can delete their own pod rooms" on pod_rooms
    for delete using (
        exists (select 1 from pods where pods.id = pod_rooms.pod_id and pods.host_id = auth.uid())
    );

drop policy if exists "Hosts can delete their own pods" on pods;
create policy "Hosts can delete their own pods" on pods
    for delete using (host_id = auth.uid());

-- reservations.sql only ever gave a guest delete rights over their own
-- rows — a host clearing reservations off a pod they're deleting needed
-- its own policy.
drop policy if exists "Hosts can delete reservations on their own pods" on reservations;
create policy "Hosts can delete reservations on their own pods" on reservations
    for delete using (
        exists (select 1 from pods where pods.id = reservations.pod_id and pods.host_id = auth.uid())
    );
