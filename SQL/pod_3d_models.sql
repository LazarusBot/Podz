-- Adds the column PodsStore.createPod writes a scanned pod's model URL
-- into, plus the UPDATE policy that write needs — pods only had
-- INSERT (host_accounts.sql) and DELETE (host_pod_management.sql)
-- policies before this. No migration tooling wired up for this project,
-- same as every other file in SQL/ — paste this whole file into the
-- Supabase SQL editor and run it once.

alter table pods add column if not exists model_url text;

drop policy if exists "Hosts can update their own pods" on pods;
create policy "Hosts can update their own pods" on pods
    for update using (host_id = auth.uid());

-- Manual step, same as pod-photos/avatars/post-photos: create a
-- "pod-models" Storage bucket in the Supabase dashboard (public read,
-- same as the others) before PodsStore's model upload will work.
