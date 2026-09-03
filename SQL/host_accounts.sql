-- Host accounts: any signed-in user can become a host (no separate host
-- account type — see the "how should host accounts work" discussion this
-- came out of) and, once they are, create their own pods. No migration
-- tooling wired up for this project, same as reservations.sql — paste
-- this whole file into the Supabase SQL editor and run it once.

alter table profiles add column if not exists is_host boolean not null default false;

alter table pods add column if not exists host_id uuid references profiles(id);

-- pods has no RLS policies tracked anywhere in this repo (the table
-- predates SQL/ entirely) — this only adds the one this feature needs
-- (a host inserting their own pod) without assuming anything about
-- whether RLS is even enabled on pods today, or what a pre-existing
-- select policy looks like.
alter table pods enable row level security;

drop policy if exists "Anyone can view pods" on pods;
create policy "Anyone can view pods" on pods
    for select using (true);

drop policy if exists "Hosts can insert their own pods" on pods;
create policy "Hosts can insert their own pods" on pods
    for insert with check (
        host_id = auth.uid()
        and exists (select 1 from profiles where id = auth.uid() and is_host)
    );
